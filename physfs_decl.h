-- Filesystem Mapper Library
-- PhysFS Declaration Helper
-- by zorg § ISC @ 2018-

return [[
	// Needed for deprecated function check.
	typedef struct {
		unsigned char major;
		unsigned char minor;
		unsigned char patch;
	} PHYSFS_Version;

	void PHYSFS_getLinkedVersion(PHYSFS_Version * ver);

	// Needed for error-checking.
	const char * PHYSFS_getLastError(void);

	// Needed to modify Löve's own mountpoints, and to sidestep its "defenses".
	int PHYSFS_mount(
		const char * newDir, const char * mountPoint, int appendToPath
	);

	int PHYSFS_removeFromSearchPath(const char * oldDir);
	int PHYSFS_unmount             (const char * oldDir);

	// Note: PHYSFS_setWriteDir will fail (and fail to change the write dir)
	//       if the current write directory still has files open in it.

	const char * PHYSFS_getWriteDir(void);
	int          PHYSFS_setWriteDir(const char* newDir);

	// May be needed in case we want to mimic löve's internal code more closely.
	int PHYSFS_isInit(void);
]]