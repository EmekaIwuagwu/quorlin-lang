contract Test:
    is_paused: bool = False

    @external
    fn test():
        self.is_paused = not True
