#pragma author WerWolv
#pragma description Microsoft Hyper-V Virtual Hard Disk

import std.io;
import std.ptr;
import std.core;

import type.guid;
import type.size;

using BitfieldOrder = std::core::BitfieldOrder;

struct FileTypeIdentifier {
	char signature[8];
	char16 creator[256];
	padding[0x1'0000 - sizeof(signature) - sizeof(creator)];
};

struct DataSector {
	u32 sequenceHigh;
	u8 data[4084];
	u32 sequenceLow;
} [[static]];

struct ZeroDescriptor {
	padding[4];
	u64 zeroLength;
	DataSector *dataSector : u64;
	u64 sequenceNumber;
} [[static]];

struct DataDescriptor {
	u32 trailingBytes;
	u64 leadingBytes;
	DataSector *dataSector : u64;
	u64 sequenceNumber;
} [[static]];

struct LogDescriptor {
	char signature[4];

	if (signature == "zero")
		ZeroDescriptor descriptor [[inline]];
	else if (signature == "desc")
		DataDescriptor descriptor [[inline]];
};

struct LogEntry {
	char signature[4];
	u32 checksum;
	type::Size32 entryLength;
	u32 tail;
	u64 sequenceNumber;
	u32 descriptorCount;
	padding[4];
	type::GUID logGuid;
	u64 flushedFileOffset;
	u64 lastFileOffset;
} [[static]];

bitfield BAT {
	State 			: 3;
	padding 		: 17;
	FileOffsetMB 	: 44;
} [[bitfield_order(BitfieldOrder::LeastToMostSignificant, 64)]];

bitfield MetadataEntryFlags {
	IsUser 			: 1;
	IsVirtualDisk 	: 1;
	IsRequired 		: 1;
	padding			: 29;
};

bitfield FileParameterFlags {
	LeaveBlockAllocated : 1;
	HasParent			: 1;
	padding				: 30;
};

struct MetadataFileParameters {
	type::Size32 blockSize;
	FileParameterFlags flags;
};

struct MetadataVirtualDiskSize {
	type::Size64 virtualDiskSize;
};

struct MetadataVirtualDiskID {
	type::GUID virtualDiskID;
};

struct MetadataLogicalSectorSize {
	type::Size32 logicalSectorSize;
};

struct MetadataPhysicalSectorSize {
	type::Size32 physicalSectorSize;
};

struct ParentLocatorEntry {
	u32 keyOffset;
	u32 valueOffset;
	u16 keyLength;
	u16 valueLength;

	char16 key[keyLength / 2] @ addressof(parent) + keyOffset;
	char16 value[valueLength / 2] @ addressof(parent) + valueOffset;
};

struct MetadataParentLocator {
	type::GUID locatorType;
	padding[2];
	u16 keyValueCount;
	ParentLocatorEntry entries[keyValueCount];
};

struct MetadataTableEntry {
	type::GUID itemID;
	u32 dataOffset;
	type::Size32 length;
	MetadataEntryFlags flags;
	padding[4];

	if (std::core::formatted_value(itemID) == "{CAA16737-FA36-4D43-B3B6-33F0AA44E76B}")
		MetadataFileParameters fileParameters @ addressof(parent) + dataOffset;
	else if (std::core::formatted_value(itemID) == "{2FA54224-CD1B-4876-B211-5DBED83BF4B8}")
		MetadataVirtualDiskSize virtualDiskSize @ addressof(parent) + dataOffset;
	else if (std::core::formatted_value(itemID) == "{BECA12AB-B2E6-4523-93EF-C309E000C746}")
		MetadataVirtualDiskID virtualDiskId @ addressof(parent) + dataOffset;
	else if (std::core::formatted_value(itemID) == "{8141BF1D-A96F-4709-BA47-F233A8FAAB5F}")
		MetadataLogicalSectorSize logicalSectorSize @ addressof(parent) + dataOffset;
	else if (std::core::formatted_value(itemID) == "{CDA348C7-445D-4471-9CC9-E9885251C556}")
		MetadataPhysicalSectorSize physicalSectorSize @ addressof(parent) + dataOffset;
	else if (std::core::formatted_value(itemID) == "{A8D35F2D-B30B-454D-ABF7-D3D84834AB0C}")
		MetadataParentLocator parentLocator @ addressof(parent) + dataOffset;
};

struct MetadataRegion {
	char signature[8];
	padding[2];
	u16 entryCount;
	padding[20];
	MetadataTableEntry entries[entryCount];
};

struct RegionTableEntry {
	type::GUID guid;
	u64 fileOffset;
	type::Size32 length;
	u32 required;

	if (std::core::formatted_value(guid) == "{2DC27766-F623-4200-9D64-115E9BFD4A08}")
		BAT bat @ fileOffset;
	else if (std::core::formatted_value(guid) == "{8B7CA206-4790-4B9A-B8FE-575F050F886E}")
		MetadataRegion metadata @ fileOffset;
};

struct RegionTable {
	char signature[4];
	u32 checksum;
	u32 entryCount;
	padding[4];

	RegionTableEntry entries[entryCount];
};

struct Header {
	char signature[4];
	u32 checksum;
	u64 sequenceNumber;
	type::GUID fileWriteGuid, dataWriteGuid, logGuid;
	u16 logVersion;
	u16 version;
	type::Size32 logLength;
	LogEntry *log : u64;
	padding[4016];
};

struct VHDX {
	FileTypeIdentifier fileTypeIdentifier;

	Header header                   @ 0x1'0000;
	Header headerBackup             @ 0x2'0000;

	RegionTable regionTable         @ 0x3'0000;
	RegionTable regionTableBackup   @ 0x4'0000;
};

VHDX vhdx @ 0x00;