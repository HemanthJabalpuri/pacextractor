#!/usr/bin/env lua

-- This program is used for unpacking .pac file of Spreadtrum Firmware used in SPD Flash Tool for flashing.
-- requires Lua 5.3+
--
-- Author: HemanthJabalpuri
-- Created: April 2nd 2022
--
-- This file has been put into the public domain.
-- You can do whatever you want with this file.

-- fails in Windows when file is greater that 2GiB. See below link
-- http://lua-users.org/lists/lua-l/2015-05/msg00315.html
-- http://lua-users.org/lists/lua-l/2015-05/msg00370.html

function abort(msg)
  io.stderr:write(msg .. "\n")
  os.exit()
end

if #arg < 1 then
  abort("Usage: pacExtractor.lua [-d] [-c] pacfile [outdir]\n" .. "\t-d\tenable debug output\n" .. "\t-c\tcheck and verify crc")
end

debug, checkCRC = false, false
pacf, outdir = nil, nil
bufsize = 1024 * 1024

local i = 1
while i <= #arg do
  if arg[i] == "-d" then debug = true
  elseif arg[i] == "-c" then checkCRC = true
  elseif not pacf then pacf = arg[i]
  elseif not outdir then outdir = arg[i]
  end
  i = i + 1
end

f = io.open(pacf, "rb")
data = f:read(2124)

fiveSpaces = "     "

crc16_table = {
  0x0000, 0xc0c1, 0xc181, 0x0140, 0xc301, 0x03c0, 0x0280, 0xc241,
  0xc601, 0x06c0, 0x0780, 0xc741, 0x0500, 0xc5c1, 0xc481, 0x0440,
  0xcc01, 0x0cc0, 0x0d80, 0xcd41, 0x0f00, 0xcfc1, 0xce81, 0x0e40,
  0x0a00, 0xcac1, 0xcb81, 0x0b40, 0xc901, 0x09c0, 0x0880, 0xc841,
  0xd801, 0x18c0, 0x1980, 0xd941, 0x1b00, 0xdbc1, 0xda81, 0x1a40,
  0x1e00, 0xdec1, 0xdf81, 0x1f40, 0xdd01, 0x1dc0, 0x1c80, 0xdc41,
  0x1400, 0xd4c1, 0xd581, 0x1540, 0xd701, 0x17c0, 0x1680, 0xd641,
  0xd201, 0x12c0, 0x1380, 0xd341, 0x1100, 0xd1c1, 0xd081, 0x1040,
  0xf001, 0x30c0, 0x3180, 0xf141, 0x3300, 0xf3c1, 0xf281, 0x3240,
  0x3600, 0xf6c1, 0xf781, 0x3740, 0xf501, 0x35c0, 0x3480, 0xf441,
  0x3c00, 0xfcc1, 0xfd81, 0x3d40, 0xff01, 0x3fc0, 0x3e80, 0xfe41,
  0xfa01, 0x3ac0, 0x3b80, 0xfb41, 0x3900, 0xf9c1, 0xf881, 0x3840,
  0x2800, 0xe8c1, 0xe981, 0x2940, 0xeb01, 0x2bc0, 0x2a80, 0xea41,
  0xee01, 0x2ec0, 0x2f80, 0xef41, 0x2d00, 0xedc1, 0xec81, 0x2c40,
  0xe401, 0x24c0, 0x2580, 0xe541, 0x2700, 0xe7c1, 0xe681, 0x2640,
  0x2200, 0xe2c1, 0xe381, 0x2340, 0xe101, 0x21c0, 0x2080, 0xe041,
  0xa001, 0x60c0, 0x6180, 0xa141, 0x6300, 0xa3c1, 0xa281, 0x6240,
  0x6600, 0xa6c1, 0xa781, 0x6740, 0xa501, 0x65c0, 0x6480, 0xa441,
  0x6c00, 0xacc1, 0xad81, 0x6d40, 0xaf01, 0x6fc0, 0x6e80, 0xae41,
  0xaa01, 0x6ac0, 0x6b80, 0xab41, 0x6900, 0xa9c1, 0xa881, 0x6840,
  0x7800, 0xb8c1, 0xb981, 0x7940, 0xbb01, 0x7bc0, 0x7a80, 0xba41,
  0xbe01, 0x7ec0, 0x7f80, 0xbf41, 0x7d00, 0xbdc1, 0xbc81, 0x7c40,
  0xb401, 0x74c0, 0x7580, 0xb541, 0x7700, 0xb7c1, 0xb681, 0x7640,
  0x7200, 0xb2c1, 0xb381, 0x7340, 0xb101, 0x71c0, 0x7080, 0xb041,
  0x5000, 0x90c1, 0x9181, 0x5140, 0x9301, 0x53c0, 0x5280, 0x9241,
  0x9601, 0x56c0, 0x5780, 0x9741, 0x5500, 0x95c1, 0x9481, 0x5440,
  0x9c01, 0x5cc0, 0x5d80, 0x9d41, 0x5f00, 0x9fc1, 0x9e81, 0x5e40,
  0x5a00, 0x9ac1, 0x9b81, 0x5b40, 0x9901, 0x59c0, 0x5880, 0x9841,
  0x8801, 0x48c0, 0x4980, 0x8941, 0x4b00, 0x8bc1, 0x8a81, 0x4a40,
  0x4e00, 0x8ec1, 0x8f81, 0x4f40, 0x8d01, 0x4dc0, 0x4c80, 0x8c41,
  0x4400, 0x84c1, 0x8581, 0x4540, 0x8701, 0x47c0, 0x4680, 0x8641,
  0x8201, 0x42c0, 0x4380, 0x8341, 0x4100, 0x81c1, 0x8081, 0x4040
}

function getString(off, n)
  local b = { string.unpack(string.rep("H", n), data, off) }
  local str = ""
  -- instead starts from 1 not 0 like most languages
  -- string.unpack also returns the index of the first unread byte. so #b - 1
  for i = 1, #b - 1 do
    -- here ~= stands for 'not eqaul to'. lua uses ~= instead of !=
    if b[i] ~= 0 then
      -- lua uses .. for appending, not +
      str = str .. string.char(b[i])
    end
  end
  return str
end

function getInt(off)
  return string.unpack("I4", data, off)
end

function getShort(off)
  return string.unpack("H", data, off)
end

function crc16(dat, crc)
  for i = 1, #dat do
    b = string.unpack("B", dat, i)
    -- do note that XOR in lua is ~ not ^ like in most languages
    crc = (crc >> 8) ~ crc16_table[((crc ~ b) & 0xff) + 1]
  end
  return crc;
end

function printPacHdr()
  print("Version\t\t= " .. pHdr.szVersion)
  if pHdr.dwHiSize == 0x0000 then
    print("Size\t\t= " .. pHdr.dwLoSize)
  else
    print("HiSize\t\t= " .. pHdr.dwHiSize)
    print("LoSize\t\t= " .. pHdr.dwLoSize)
    print("Size\t\t= " .. pHdr.dwHiSize * 0x100000000 + pHdr.dwLoSize)
  end
  print("PrdName\t\t= " .. pHdr.productName)
  print("FirmwareName\t= " .. pHdr.firmwareName)
  print("FileCount\t= " .. pHdr.partitionCount)
  print("FileOffset\t= " .. pHdr.partitionsListStart)
  print("PrdAlias\t= " .. pHdr.szPrdAlias)
  print("CRC1\t\t= " .. pHdr.wCRC1)
  print("CRC2\t\t= " .. pHdr.wCRC2)
  print("\n")
end

function printFileHdr(fHdr)
  print("FileID\t\t= " .. fHdr.partitionName)
  print("FileName\t= " .. fHdr.fileName)
  if fHdr.hiPartitionSize == 0x0000 then
    print("FileSize\t= " .. fHdr.loPartitionSize)
  else
    print("HiFileSize\t= " .. fHdr.hiPartitionSize)
    print("LoFileSize\t= " .. fHdr.loPartitionSize)
    print("FileSize\t= " .. fHdr.hiPartitionSize * 0x100000000 + fHdr.loPartitionSize)
  end
  if fHdr.hiDataOffset == 0x0000 then
    print("DataOffset\t= " .. fHdr.loDataOffset)
  else
    print("HiDataOffset\t= " .. fHdr.hiDataOffset)
    print("HiDataOffset\t= " .. fHdr.loDataOffset)
    print("DataOffset\t= " .. fHdr.hiDataOffset * 0x100000000 + fHdr.loDataOffset)
  end
  print("")
end

function checkCRCf()
  print("Checking CRC1")
  f:seek("set") -- seek starts from 0, not 1 like in tables
  local crc1val = crc16(f:read(2120), 0)
  if crc1val ~= pHdr.wCRC1 then
    if debug then
      print("Computed CRC1 = " .. crc1val .. ", CRC1 in PAC = " .. pHdr.wCRC1)
    end
    print("CRC Check failed for CRC1")
  end
  print("Checking CRC2")
  f:seek("set", 2124)
  local buf_size = bufsize
  local tempsize = fsize - 2124
  local tsize = tempsize
  local crc2val = 0
  while tempsize > 0 do
    if tempsize < buf_size then
      buf_size = tempsize
    end
    -- there are no -= like operators in lua
    tempsize = tempsize - buf_size
    crc2val = crc16(f:read(buf_size), crc2val)
    prg = math.floor(100 - ((100 * tempsize) / tsize))
    io.write("\r", prg, "%")
    -- io.flush()
  end
  print("\r" .. fiveSpaces)
  if crc2val ~= pHdr.wCRC2 then
    if debug then
      print("Computed CRC2 = " .. crc2val .. ", CRC2 in PAC = " .. pHdr.wCRC2)
    end
    print("CRC Check failed for CRC2")
  end
end

function extractFile(fHdr)
  tempsize = fHdr.hiPartitionSize * 0x100000000 + fHdr.loPartitionSize
  if tempsize == 0 then
    -- there is no 'continue' in lua if we are in loop
    return
  end
  io.write(fiveSpaces .. fHdr.fileName)
  f:seek("set", fHdr.hiDataOffset * 0x100000000 + fHdr.loDataOffset)
  size = bufsize
  tsize = tempsize
  filepath = outdir .. "/" .. fHdr.fileName
  of = io.open(filepath, "wb")
  while tempsize > 0 do
    if tempsize < size then
      size = tempsize
    end
    dat = f:read(size)
    tempsize = tempsize - size
    of:write(dat)
    prg = math.floor(100 - ((100 * tempsize) / tsize))
    io.write("\r", prg, "%")
    -- io.flush()
  end
  print("\r" .. fHdr.fileName .. fiveSpaces)
  of:close()
end

fsize = f:seek("end")
if fsize < 2124 then
  abort(pacf .. " is not a PAC firmware.")
end

pHdr = {
  szVersion = getString(1, 22),
  dwHiSize = getInt(45),
  dwLoSize = getInt(49),
  productName = getString(53, 256),
  firmwareName = getString(565, 256),
  partitionCount = getInt(1077),
  partitionsListStart = getInt(1081),
  szPrdAlias = getString(1105, 100),
  wCRC1 = getShort(2121),
  wCRC2 = getShort(2123)
}

if debug then
  printPacHdr()
end

if pHdr.szVersion ~= "BP_R1.0.0" and pHdr.szVersion ~= "BP_R2.0.1" then
  abort("Unsupported PAC version")
end

dwSize = pHdr.dwHiSize * 0x100000000 + pHdr.dwLoSize
if dwSize ~= fsize then
  abort("Bin packet's size is not correct")
end

if checkCRC then
  checkCRCf()
end

fHdrs = {}
f:seek("set", pHdr.partitionsListStart)
for i = 1, pHdr.partitionCount do
  data = f:read(2580)
  fHdrs[i] = {
    length = getInt(1),
    partitionName = getString(5, 256),
    fileName = getString(517, 256),
    hiPartitionSize = getInt(1533),
    hiDataOffset = getInt(1537),
    loPartitionSize = getInt(1541),
    loDataOffset = getInt(1553),
  }
  if fHdrs[i].length ~= 2580 then
    abort("Unknown Partition Header format found")
  end
  if debug then
    printFileHdr(fHdrs[i])
  end
end


print("\nExtracting...\n")

if not outdir then outdir = "outdir" end
if not os.execute("mkdir " .. outdir) then
  abort("Can't create directory " .. outdir)
end

for i = 1, pHdr.partitionCount do
  extractFile(fHdrs[i])
end

f:close()
