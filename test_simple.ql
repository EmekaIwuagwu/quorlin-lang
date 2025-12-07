# Simple Counter Contract
contract Counter:
    _count: uint64
    
    @external
    fn increment():
        self._count = self._count + 1
    
    @external
    fn get_count() -> uint64:
        return self._count
