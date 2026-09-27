import shellout

pub fn get_commit_id() -> String {
  let assert Ok(revision) =
    shellout.command("git", ["rev-parse", "HEAD"], ".", [])
  revision
}
