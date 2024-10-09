meta:
  id: pac
  title: Spreadtrum/Unisoc .pac firmware file extractor
  file-extension: pac
  license: CC0-1.0
  endian: le
seq:
  - id: pac_header
    type: pac_header
    size: 2124
  - id: partition_header
    type: partition_header
    size: 2580
    repeat: expr
    repeat-expr: pac_header.partition_count
types:
  pac_header:
    seq:
      - id: sz_version
        size: 22 * 2
        type: str
        encoding: UTF-16LE
        valid:
          any-of:
            - '"BP_R1.0.0\0\0\0\0\0\0\0\0\0\0\0\0\0"'
            - '"BP_R2.0.1\0\0\0\0\0\0\0\0\0\0\0\0\0"'
      - id: dw_hi_size
        type: u4
      - id: dw_lo_size
        type: u4
      - id: product_name
        type: str
        size: 256 * 2
        encoding: UTF-16LE
      - id: firmware_name
        type: str
        size: 256 * 2
        encoding: UTF-16LE
      - id: partition_count
        type: u4
      - id: partitions_list_start
        type: u4
        valid: 2124
      - id: dw_mode
        type: u4
        valid:
          any-of: [ 0, 1 ]
      - id: dw_flash_type
        type: u4
        valid:
          any-of: [ 0, 1 ]
      - id: dw_nand_strategy
        type: u4
        valid:
          any-of: [ 0, 1 ]
      - id: dw_is_nv_backup
        type: u4
        valid:
          any-of: [ 0, 1 ]
      - id: dw_nand_page_type
        type: u4
        valid:
          any-of: [ 0, 1 ]
      - id: sz_prd_alias
        type: str
        size: 100 * 2
        encoding: UTF-16LE
      - id: dw_oma_dm_product_flag
        type: u4
        valid:
          any-of: [ 0, 1 ]
      - id: dw_is_oma_dm
        type: u4
        valid:
          any-of: [ 0, 1 ]
      - id: dw_is_preload
        type: u4
        valid:
          any-of: [ 0, 1 ]
      - id: reserved
        size: 200 * 4
      - id: dw_magic
        contents: [0xfa, 0xff, 0xfa, 0xff]
      - id: w_crc1
        type: u2
      - id: w_crc2
        type: u2
  partition_header:
    seq:
      - id: length
        type: u4
        valid: 2580
      - id: partition_name
        type: str
        size: 256 * 2
        encoding: UTF-16LE
      - id: file_name
        type: str
        size: 256 * 2
        encoding: UTF-16LE
      - id: reserved
        size: 252 * 2
      - id: hi_partition_size
        type: u4
      - id: hi_data_offset
        type: u4
      - id: lo_partition_size
        type: u4
      - id: n_file_flag
        type: u4
      - id: n_check_flag
        type: u4
        valid:
          any-of: [ 0, 1 ]
      - id: lo_data_offset
        type: u4
      - id: dw_can_omit_flag
        type: u4
        valid:
          any-of: [ 0, 1 ]
      - id: dw_addr_num
        type: u4
      - id: dw_addr
        type: u4
        repeat: expr
        repeat-expr: 5
      - id: dw_reserved
        size: 249 * 4
    -webide-representation: '{file_name} off:{ofs_part} len:{len_part}'
    instances:
      ofs_part:
        value: hi_data_offset * 0x100000000 + lo_data_offset
      len_part:
        value: hi_partition_size * 0x100000000 + lo_partition_size
      part:
        io: _root._io
        pos: ofs_part
        size: len_part
