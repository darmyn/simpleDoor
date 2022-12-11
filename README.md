# How to use?

- Copy the code in `door.lua` and paste it into a module script inside of ReplicatedStorage.
- Have the server and client initialize an object passing the same door model as an argument
- Voila!

You can customize the global values within the module, or apply the following attributes to the model for customization:

`targetAngle1` -> the angle the door will rotate too when activating it from one direction

`targetAngle2` -> the angle the door will rotate too when activating it from the other direction

`activationRange` -> how far away the client can interact with the doors lock and handle (server sanity checks included)

`defaultAngle` -> the angle that is considered "closed", typically 0.

IMPORTANT:

The door model must follow this exact structure:

```
> Model
  > Handle -> the part that will be clicked to open and close the door
  > Hinge -> the part that will rotate and all other parts within the model will weld too
  > Lock -> the part that will be clicked to lock the door

any other parts in the model will be automatically welded to the hinge.
```
