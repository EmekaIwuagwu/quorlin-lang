use std::path::PathBuf;

pub fn run(
    _file: PathBuf,
    _target: String,
    _output: Option<PathBuf>,
    _emit_ir: bool,
    _optimize: bool,
) -> Result<(), Box<dyn std::error::Error>> {
    println!("Compile command not yet implemented");
    Err("Not implemented yet".into())
}
