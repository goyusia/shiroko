import child_process

pub fn get_commit_id() -> String {
  let assert Ok(revision) = child_process.shell("git rev-parse HEAD")
  revision
}
