//! The picture the sidebar shows beside the player's name: the one Xbox has for the Microsoft
//! account (`account::picture_url`), else the face of the player's own skin (the URL
//! `accounts.json` keeps), else the Minecraft head the game's files have for the account's UUID.
//!
//! Both pictures are saved under the launcher's data folder, so the window has one before any
//! network answer and keeps showing it while a refresh fails, and both are asked for again once a
//! day.
use std::io::Read;
use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime};

/// How old a saved picture may be before it is fetched again.
pub const REFRESH_AFTER: Duration = Duration::from_secs(24 * 60 * 60);

/// The side of the saved account picture: a square cut from the middle of Xbox's, big enough for
/// every size the window draws it at.
const SIDE: u32 = 256;

/// Where pictures are saved: `avatars/` in the launcher's data folder.
fn dir() -> PathBuf {
    crate::backend::data_dir().join("avatars")
}

/// Where an account's Xbox picture is saved: `avatars/<uuid>.png`.
pub fn path(uuid: &str) -> PathBuf {
    dir().join(format!("{uuid}.png"))
}

/// The saved Xbox picture, when the launcher has one.
pub fn cached(uuid: &str) -> Option<PathBuf> {
    saved(&path(uuid))
}

/// Whether to ask Xbox again: no saved picture, or one saved over a day ago.
pub fn due(uuid: &str) -> bool {
    !fresh(&path(uuid))
}

/// Ask Xbox for `uuid`'s picture and save it: the saved path, or none when it isn't due yet.
/// A picture that can't be fetched leaves the saved one alone, so the window keeps its picture.
pub fn refresh(uuid: &str) -> Result<Option<PathBuf>, String> {
    if !due(uuid) {
        return Ok(None);
    }
    let Some(url) = crate::account::picture_url(uuid)? else {
        return Ok(None);
    };
    let picture = image::load_from_memory(&download(&url)?)
        .map_err(|_| "Your account's picture wasn't a picture.".to_string())?;
    // A square from the middle: Xbox's pictures are not all the same shape.
    let side = picture.width().min(picture.height());
    let square = picture
        .crop_imm(
            (picture.width() - side) / 2,
            (picture.height() - side) / 2,
            side,
            side,
        )
        .resize_exact(SIDE, SIDE, image::imageops::FilterType::Lanczos3);
    save(&square, &path(uuid)).map(Some)
}

/// The face of the account's own skin, from the texture URL `accounts.json` keeps (a public file,
/// no sign-in): `avatars/<uuid>.face.png`, drawn eight texels to a side as the game's tabs do.
/// None when the skin can't be had, which leaves the default head.
pub fn face(uuid: &str, skin_url: &str) -> Option<PathBuf> {
    let path = dir().join(format!("{uuid}.face.png"));
    if fresh(&path) {
        return saved(&path);
    }
    let pixels = crate::heads::face(&download(skin_url).ok()?)?;
    let mut tile = image::RgbaImage::new(8, 8);
    for (i, p) in pixels.iter().enumerate() {
        tile.put_pixel((i % 8) as u32, (i / 8) as u32, image::Rgba(*p));
    }
    let face = image::imageops::resize(&tile, 64, 64, image::imageops::FilterType::Nearest);
    save(&image::DynamicImage::ImageRgba8(face), &path).ok()?;
    Some(path)
}

/// A saved picture that is there and has something in it.
fn saved(path: &Path) -> Option<PathBuf> {
    (std::fs::metadata(path).ok()?.len() > 0).then(|| path.to_path_buf())
}

/// Whether `path` holds a picture saved less than a day ago.
fn fresh(path: &Path) -> bool {
    std::fs::metadata(path)
        .and_then(|m| m.modified())
        .is_ok_and(|saved| {
            SystemTime::now()
                .duration_since(saved)
                .is_ok_and(|age| age <= REFRESH_AFTER)
        })
}

/// Write `picture` to `path`: beside it and renamed over it, so a window reading it never sees
/// half a picture.
fn save(picture: &image::DynamicImage, path: &Path) -> Result<PathBuf, String> {
    if let Some(dir) = path.parent() {
        std::fs::create_dir_all(dir).map_err(|e| e.to_string())?;
    }
    let part = path.with_extension("png.part");
    picture
        .save_with_format(&part, image::ImageFormat::Png)
        .map_err(|e| e.to_string())?;
    std::fs::rename(&part, path).map_err(|e| e.to_string())?;
    Ok(path.to_path_buf())
}

/// The bytes at `url`: the launcher's user agent, its 20 s timeout, and the player's proxy when
/// one is set, as the sign-in and the downloads go out.
fn download(url: &str) -> Result<Vec<u8>, String> {
    let response = crate::proxy::agent(
        ureq::AgentBuilder::new()
            .timeout(Duration::from_secs(20))
            .user_agent(&format!("horizon-launcher/{}", crate::backend::VERSION)),
        url,
    )
    .build()
    .get(url)
    .call()
    .map_err(|_| "Could not download the picture.".to_string())?;
    let mut bytes = Vec::new();
    response
        .into_reader()
        .take(4 * 1024 * 1024)
        .read_to_end(&mut bytes)
        .map_err(|_| "Could not read the picture.".to_string())?;
    Ok(bytes)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_picture_lives_beside_the_launcher_data() {
        assert!(path("abc123").ends_with("avatars/abc123.png"));
    }

    #[test]
    fn a_missing_picture_is_not_saved_and_is_due() {
        let uuid = "0000000000000000000000000000test";
        assert!(due(uuid));
        assert_eq!(cached(uuid), None);
        assert!(!fresh(&path(uuid)));
    }
}
