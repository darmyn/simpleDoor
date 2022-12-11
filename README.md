# How to use?

Simple, you must initialize the object on both the client and the server.

You can customize the global values within the module, or apply the following attributes to the model:

`targetAngle1` -> the angle the door will rotate too when activating it from one direction
`targetAngle2` -> the angle the door will rotate too when activating it from the other direction
`activationRange` -> how far away the client can interact with the doors lock and handle (server sanity checks included)
`defaultAngle` -> the angle that is considered "closed", typically 0.
