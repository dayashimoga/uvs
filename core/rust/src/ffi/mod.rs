use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int, c_uint};
use std::path::Path;

use crate::audio::{extract_waveform, AudioBuffer};
use crate::project::Project;
use crate::render::HardwareCapabilities;
use crate::timeline::TimecodeConfig;

#[no_mangle]
pub extern "C" fn uvs_core_version() -> *mut c_char {
    let s = CString::new("0.1.0-production").unwrap();
    s.into_raw()
}

#[no_mangle]
pub extern "C" fn uvs_detect_hardware() -> *mut c_char {
    let caps = HardwareCapabilities::detect();
    let json = serde_json::to_string(&caps).unwrap_or_else(|_| "{}".into());
    CString::new(json).unwrap().into_raw()
}

#[no_mangle]
pub extern "C" fn uvs_project_new(
    name: *const c_char,
    width: c_uint,
    height: c_uint,
    fps_num: i64,
    fps_den: i64,
    drop_frame: c_int,
) -> *mut c_char {
    let name_str = if name.is_null() {
        "Untitled Project"
    } else {
        unsafe { CStr::from_ptr(name).to_str().unwrap_or("Untitled Project") }
    };

    let config = TimecodeConfig {
        num: fps_num,
        den: fps_den,
        drop_frame: drop_frame != 0,
    };

    let proj = Project::new(name_str, width, height, config);
    let json = proj.to_json().unwrap_or_else(|_| "{}".into());
    CString::new(json).unwrap().into_raw()
}

#[no_mangle]
pub extern "C" fn uvs_project_save_atomic(project_json: *const c_char, target_path: *const c_char) -> *mut c_char {
    if project_json.is_null() || target_path.is_null() {
        return CString::new("{\"error\": \"Null argument\"}").unwrap().into_raw();
    }

    let json_str = unsafe { CStr::from_ptr(project_json).to_str().unwrap_or("") };
    let path_str = unsafe { CStr::from_ptr(target_path).to_str().unwrap_or("") };

    match Project::from_json(json_str) {
        Ok(mut proj) => {
            match proj.save_atomic(Path::new(path_str)) {
                Ok(_) => CString::new("{\"status\": \"ok\"}").unwrap().into_raw(),
                Err(e) => CString::new(format!("{{\"error\": \"{}\"}}", e)).unwrap().into_raw(),
            }
        }
        Err(e) => CString::new(format!("{{\"error\": \"{}\"}}", e)).unwrap().into_raw(),
    }
}

#[no_mangle]
pub extern "C" fn uvs_project_load(path: *const c_char) -> *mut c_char {
    if path.is_null() {
        return CString::new("{\"error\": \"Null path\"}").unwrap().into_raw();
    }
    let path_str = unsafe { CStr::from_ptr(path).to_str().unwrap_or("") };
    match Project::load_from_file(Path::new(path_str)) {
        Ok(proj) => {
            let json = proj.to_json().unwrap_or_else(|_| "{}".into());
            CString::new(json).unwrap().into_raw()
        }
        Err(e) => CString::new(format!("{{\"error\": \"{}\"}}", e)).unwrap().into_raw(),
    }
}

#[no_mangle]
pub extern "C" fn uvs_waveform_summary(sample_count: usize, target_points: usize) -> *mut c_char {
    let buf = AudioBuffer::new(2, 48000, sample_count);
    let summary = extract_waveform(&buf, target_points);
    let json = serde_json::to_string(&summary).unwrap_or_else(|_| "{}".into());
    CString::new(json).unwrap().into_raw()
}

#[no_mangle]
pub extern "C" fn uvs_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            let _ = CString::from_raw(ptr);
        }
    }
}
