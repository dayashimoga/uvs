use crate::project::Project;
use crate::timeline::{Clip, RationalTime, Transform};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum Action {
    AddClip {
        track_id: String,
        clip: Clip,
    },
    RemoveClip {
        track_id: String,
        clip: Clip,
    },
    MoveClip {
        track_id: String,
        clip_id: String,
        from_start: RationalTime,
        to_start: RationalTime,
    },
    TrimClip {
        track_id: String,
        clip_id: String,
        old_in: RationalTime,
        old_out: RationalTime,
        old_duration: RationalTime,
        new_in: RationalTime,
        new_out: RationalTime,
        new_duration: RationalTime,
    },
    UpdateTransform {
        track_id: String,
        clip_id: String,
        old_transform: Transform,
        new_transform: Transform,
    },
    UpdateVolume {
        track_id: String,
        clip_id: String,
        old_volume: f64,
        new_volume: f64,
    },
}

impl Action {
    pub fn inverse(&self) -> Action {
        match self {
            Action::AddClip { track_id, clip } => Action::RemoveClip {
                track_id: track_id.clone(),
                clip: clip.clone(),
            },
            Action::RemoveClip { track_id, clip } => Action::AddClip {
                track_id: track_id.clone(),
                clip: clip.clone(),
            },
            Action::MoveClip { track_id, clip_id, from_start, to_start } => Action::MoveClip {
                track_id: track_id.clone(),
                clip_id: clip_id.clone(),
                from_start: *to_start,
                to_start: *from_start,
            },
            Action::TrimClip {
                track_id,
                clip_id,
                old_in,
                old_out,
                old_duration,
                new_in,
                new_out,
                new_duration,
            } => Action::TrimClip {
                track_id: track_id.clone(),
                clip_id: clip_id.clone(),
                old_in: *new_in,
                old_out: *new_out,
                old_duration: *new_duration,
                new_in: *old_in,
                new_out: *old_out,
                new_duration: *old_duration,
            },
            Action::UpdateTransform {
                track_id,
                clip_id,
                old_transform,
                new_transform,
            } => Action::UpdateTransform {
                track_id: track_id.clone(),
                clip_id: clip_id.clone(),
                old_transform: new_transform.clone(),
                new_transform: old_transform.clone(),
            },
            Action::UpdateVolume {
                track_id,
                clip_id,
                old_volume,
                new_volume,
            } => Action::UpdateVolume {
                track_id: track_id.clone(),
                clip_id: clip_id.clone(),
                old_volume: *new_volume,
                new_volume: *old_volume,
            },
        }
    }

    pub fn apply(&self, project: &mut Project) -> Result<(), String> {
        match self {
            Action::AddClip { track_id, clip } => {
                let track = project.timeline.tracks.iter_mut().find(|t| &t.id == track_id)
                    .ok_or_else(|| format!("Track not found: {}", track_id))?;
                track.add_clip(clip.clone())?;
            }
            Action::RemoveClip { track_id, clip } => {
                let track = project.timeline.tracks.iter_mut().find(|t| &t.id == track_id)
                    .ok_or_else(|| format!("Track not found: {}", track_id))?;
                track.clips.retain(|c| c.id != clip.id);
            }
            Action::MoveClip { track_id, clip_id, to_start, .. } => {
                let track = project.timeline.tracks.iter_mut().find(|t| &t.id == track_id)
                    .ok_or_else(|| format!("Track not found: {}", track_id))?;
                let clip = track.clips.iter_mut().find(|c| &c.id == clip_id)
                    .ok_or_else(|| format!("Clip not found: {}", clip_id))?;
                clip.start_time = *to_start;
                track.clips.sort_by(|a, b| a.start_time.cmp(&b.start_time));
            }
            Action::TrimClip { track_id, clip_id, new_in, new_out, new_duration, .. } => {
                let track = project.timeline.tracks.iter_mut().find(|t| &t.id == track_id)
                    .ok_or_else(|| format!("Track not found: {}", track_id))?;
                let clip = track.clips.iter_mut().find(|c| &c.id == clip_id)
                    .ok_or_else(|| format!("Clip not found: {}", clip_id))?;
                clip.in_point = *new_in;
                clip.out_point = *new_out;
                clip.duration = *new_duration;
            }
            Action::UpdateTransform { track_id, clip_id, new_transform, .. } => {
                let track = project.timeline.tracks.iter_mut().find(|t| &t.id == track_id)
                    .ok_or_else(|| format!("Track not found: {}", track_id))?;
                let clip = track.clips.iter_mut().find(|c| &c.id == clip_id)
                    .ok_or_else(|| format!("Clip not found: {}", clip_id))?;
                clip.transform = new_transform.clone();
            }
            Action::UpdateVolume { track_id, clip_id, new_volume, .. } => {
                let track = project.timeline.tracks.iter_mut().find(|t| &t.id == track_id)
                    .ok_or_else(|| format!("Track not found: {}", track_id))?;
                let clip = track.clips.iter_mut().find(|c| &c.id == clip_id)
                    .ok_or_else(|| format!("Clip not found: {}", clip_id))?;
                clip.volume = *new_volume;
            }
        }
        Ok(())
    }
}

pub struct UndoStack {
    undo_actions: Vec<Action>,
    redo_actions: Vec<Action>,
    max_depth: usize,
}

impl UndoStack {
    pub fn new(max_depth: usize) -> Self {
        Self {
            undo_actions: Vec::new(),
            redo_actions: Vec::new(),
            max_depth,
        }
    }

    pub fn push_action(&mut self, action: Action) {
        if self.undo_actions.len() >= self.max_depth {
            self.undo_actions.remove(0);
        }
        self.undo_actions.push(action);
        self.redo_actions.clear();
    }

    pub fn can_undo(&self) -> bool {
        !self.undo_actions.is_empty()
    }

    pub fn can_redo(&self) -> bool {
        !self.redo_actions.is_empty()
    }

    pub fn undo(&mut self, project: &mut Project) -> Result<bool, String> {
        if let Some(action) = self.undo_actions.pop() {
            let inv = action.inverse();
            inv.apply(project)?;
            self.redo_actions.push(action);
            Ok(true)
        } else {
            Ok(false)
        }
    }

    pub fn redo(&mut self, project: &mut Project) -> Result<bool, String> {
        if let Some(action) = self.redo_actions.pop() {
            action.apply(project)?;
            self.undo_actions.push(action);
            Ok(true)
        } else {
            Ok(false)
        }
    }
}
