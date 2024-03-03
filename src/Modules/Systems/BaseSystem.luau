local BaseSystem = {}

export type BaseSystem = {
	InitializeClient: (self: any) -> (boolean),
	InitializeServer: (self: any) -> (boolean),
}

return BaseSystem