Filesystem Mapper Library
----------------------------------------------------------

### Info

FML is a library adding extra functionality to the filesystem module of the Löve framework.

Currently supported Löve versions: 11.x

### Usage

- `require('fml')()` for the default virtual filesystem roots, or
- `require('fml')(vfsr_sav, vfsr_src, vfsr_sys)` for user-defined mountpoints for the three virtual filesystem roots.

### Additions to Filesystem functionality

- Mounting the whole filesystem through PhysFS, allowing access to files anywhere. (Depending on OS filesystem rights.)
- Allowing object constructors to load such files.

The three virtual filesystem roots are the following:
- `vfsr_sav`: The project's save directory,
- `vfsr_src`: The project's source directory (or, if fused, the zip's contents inside the executable),
- `vfsr_sys`: The mapping of the actual filesystem; on windows, the detected drive letters are mapped under a "fake" parent directory.

### API Changes

#### Modifications
- `love.filesystem.mount` and `love.filesystem.unmount` now work without limitations.
- `love.filesystem.setIdentity` changed to allow custom mountpoints for the three virtual filesystem roots.

### TODO

- Implement functionality to sidestep PhysFS' write directory limitation, allowing writing to arbitrary locations.

### License
This library licensed under the ISC License.
