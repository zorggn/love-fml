Filesystem Mapper Library
----------------------------------------------------------

### Info

FML is a library adding extra functionality to the filesystem module of the Löve framework.

Currently supported Löve versions: 11.x

### Usage

- `require('fml')()` for the default virtual filesystem roots, or
- `require('fml')(vfsr_usr, vfsr_src, vfsr_sys)` for user-defined mountpoints for the three virtual filesystem roots.

### Additions to Filesystem functionality

- Mounting the whole filesystem through PhysFS, allowing access to files anywhere. (Depending on OS filesystem rights.)

The three virtual filesystem roots are the following:
- `vfsr_usr`: The project's save directory,
- `vfsr_src`: The project's source directory (or, if fused, the zip's contents inside the executable),
- `vfsr_sys`: The mapping of the actual filesystem; on windows, the detected drive letters are mapped under a "fake" parent directory.

### API Changes

#### Modifications
- `love.filesystem.mount` now only supports platform-dependent paths for its first parameter (combinable with löve directory returning functions.), furthermore, if vfsr_sys is completely separated from either of the others, one cannot mount into that branch of the vfs.
- `love.filesystem.unmount` has the above platform-dependent path restriction.
- `love.filesystem.setIdentity` changed to allow custom mountpoints for the three virtual filesystem roots.

### TODO

- Implement functionality to sidestep PhysFS' write directory limitation, allowing (concurrent) writing to arbitrary locations.

### License
This library licensed under the ISC License.
