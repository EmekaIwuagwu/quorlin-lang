# Simple Counter Contract
contract Counter:
    _count: uint64
    _owner: address
    
    @external
    fn initialize():
        self._count = 0
    
    @external
    fn increment():
        self._count = self._count + 1
    
    @external
    fn decrement():
        require(self._count > 0, "Counter cannot go below zero")
        self._count = self._count - 1
    
    @external
    fn get_count() -> uint64:
        return self._count
    
    @external
    fn set_count(new_count: uint64):
        self._count = new_count
