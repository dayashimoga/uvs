# Technical Design Deep Dive

This document details the mathematical models, algorithms, and data structures implemented in Universal Video Studio.

---

## 1. Frame-Accurate Rational Time Math

Floating-point representations (`f32`, `f64`) accumulate precision errors over extended editing sessions, causing audio/video drift. UVS represents all timepoints as rational fractions using `num_rational::Rational64`:

$$\text{Time (seconds)} = \frac{\text{Numerator}}{\text{Denominator}}$$

Frame index $F$ at framerate $\frac{N_{\text{fps}}}{D_{\text{fps}}}$ is calculated via integer arithmetic:

$$F = \left\lfloor \frac{\text{seconds} \times N_{\text{fps}}}{D_{\text{fps}}} + 0.5 \right\rfloor$$

### SMPTE Drop-Frame Algorithm (29.97 / 59.94 FPS)
For NTSC 29.97 FPS ($\frac{30000}{1001}$), 2 frame numbers are dropped at the start of every minute, except minutes that are multiples of 10. This maintains exact wall-clock synchronization over 24-hour broadcast runs.

---

## 2. DAG Media Compositor & Alpha Blending

Active clips across tracks at playhead time $T$ are sorted by track $Z$-index and composited from bottom to top.

### Alpha Compositing
Given background color $C_{\text{bot}}$, foreground color $C_{\text{top}}$, foreground opacity $\alpha_{\text{top}}$, and blend mode result $C_{\text{blend}}$:

$$\alpha_{\text{out}} = \alpha_{\text{top}} + \alpha_{\text{bot}} \times (1 - \alpha_{\text{top}})$$
$$C_{\text{out}} = \frac{C_{\text{blend}} \times \alpha_{\text{top}} + C_{\text{bot}} \times \alpha_{\text{bot}} \times (1 - \alpha_{\text{top}})}{\alpha_{\text{out}}}$$

Supported blend equations:
* **Normal**: $C_{\text{blend}} = C_{\text{top}}$
* **Add**: $C_{\text{blend}} = \min(1.0, C_{\text{bot}} + C_{\text{top}})$
* **Multiply**: $C_{\text{blend}} = C_{\text{bot}} \times C_{\text{top}}$
* **Screen**: $C_{\text{blend}} = 1 - (1 - C_{\text{bot}}) \times (1 - C_{\text{top}})$
* **Overlay**:
  $$C_{\text{blend}} = \begin{cases} 2 C_{\text{bot}} C_{\text{top}}, & C_{\text{bot}} < 0.5 \\ 1 - 2(1 - C_{\text{bot}})(1 - C_{\text{top}}), & C_{\text{bot}} \ge 0.5 \end{cases}$$

---

## 3. Audio DSP Biquad Equalizer

The 5-band EQ implements Robert Bristow-Johnson (RBJ) audio biquad filter equations:

$$y[n] = \frac{b_0 x[n] + b_1 x[n-1] + b_2 x[n-2] - a_1 y[n-1] - a_2 y[n-2]}{a_0}$$

Bands:
1. **Low Shelf**: 100 Hz, $Q = \frac{1}{\sqrt{2}}$
2. **Low-Mid Peaking**: 500 Hz, $Q = 1.0$
3. **Mid Peaking**: 1500 Hz, $Q = 1.0$
4. **High-Mid Peaking**: 4000 Hz, $Q = 1.0$
5. **High Shelf**: 10,000 Hz, $Q = \frac{1}{\sqrt{2}}$

---

## 4. 3D LUT Trilinear Color Interpolation

A 3D LUT maps an input RGB vector into an output RGB color space using a cube lattice of dimension $N \times N \times N$.
For arbitrary floating-point input $(r, g, b) \in [0, 1]^3$:
1. Scale by $(N - 1)$ to find lattice indices $r_0 = \lfloor r \cdot (N-1) \rfloor$, $r_1 = \min(r_0 + 1, N-1)$ and fractional distances $r_d = r \cdot (N-1) - r_0$.
2. Fetch 8 bounding cube vertices: $C_{000}, C_{100}, C_{010}, C_{110}, C_{001}, C_{101}, C_{011}, C_{111}$.
3. Perform 3-stage linear interpolation across $R$, $G$, and $B$ axes.
