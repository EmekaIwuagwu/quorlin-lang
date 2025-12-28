contract SystemsFeatures:
    # 1. State variable with Generic Type
    _counters: List[uint256]
    _config: Result[uint256, string]

    fn init():
        self._counters = []
        # F-string in initialization
        self._config = Ok(100)

    # 2. Function using Generic Types in signature
    fn process_list(items: List[uint256]) -> Result[uint256, string]:
        if items.len() == 0:
            return Err("Empty list")
        return Ok(items[0])

    # 3. Match expression
    fn check_status(status: uint8) -> string:
        # Match expression result assigned to variable
        let message = match status {
            0 => "Pending",
            1 => "Active",
            2 => "Closed",
            _ => "Unknown"
        }
        return message

    # 4. F-Strings and ? Operator
    fn complex_logic(id: uint256) -> Result[string, string]:
        # Using ? to propagate error from process_list
        let val = self.process_list(self._counters)?
        
        # Using F-String for interpolation
        return Ok(f"Processed ID {id} with value {val}")

    fn match_literals(x: uint256) -> uint256:
        return match x {
            10 => 100,
            20 => 200,
            _ => 0
        }
