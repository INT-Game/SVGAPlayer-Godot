const PROTO_VERSION = 3

#
# BSD 3-Clause License
#
# Copyright (c) 2018 - 2022, Oleg Malyavkin
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# DEBUG_TAB redefine this "  " if you need, example: const DEBUG_TAB = "\t"
const DEBUG_TAB : String = "  "

enum PB_ERR {
	NO_ERRORS = 0,
	VARINT_NOT_FOUND = -1,
	REPEATED_COUNT_NOT_FOUND = -2,
	REPEATED_COUNT_MISMATCH = -3,
	LENGTHDEL_SIZE_NOT_FOUND = -4,
	LENGTHDEL_SIZE_MISMATCH = -5,
	PACKAGE_SIZE_MISMATCH = -6,
	UNDEFINED_STATE = -7,
	PARSE_INCOMPLETE = -8,
	REQUIRED_FIELDS = -9
}

enum PB_DATA_TYPE {
	INT32 = 0,
	SINT32 = 1,
	UINT32 = 2,
	INT64 = 3,
	SINT64 = 4,
	UINT64 = 5,
	BOOL = 6,
	ENUM = 7,
	FIXED32 = 8,
	SFIXED32 = 9,
	FLOAT = 10,
	FIXED64 = 11,
	SFIXED64 = 12,
	DOUBLE = 13,
	STRING = 14,
	BYTES = 15,
	MESSAGE = 16,
	MAP = 17
}

const DEFAULT_VALUES_2 = {
	PB_DATA_TYPE.INT32: null,
	PB_DATA_TYPE.SINT32: null,
	PB_DATA_TYPE.UINT32: null,
	PB_DATA_TYPE.INT64: null,
	PB_DATA_TYPE.SINT64: null,
	PB_DATA_TYPE.UINT64: null,
	PB_DATA_TYPE.BOOL: null,
	PB_DATA_TYPE.ENUM: null,
	PB_DATA_TYPE.FIXED32: null,
	PB_DATA_TYPE.SFIXED32: null,
	PB_DATA_TYPE.FLOAT: null,
	PB_DATA_TYPE.FIXED64: null,
	PB_DATA_TYPE.SFIXED64: null,
	PB_DATA_TYPE.DOUBLE: null,
	PB_DATA_TYPE.STRING: null,
	PB_DATA_TYPE.BYTES: null,
	PB_DATA_TYPE.MESSAGE: null,
	PB_DATA_TYPE.MAP: null
}

const DEFAULT_VALUES_3 = {
	PB_DATA_TYPE.INT32: 0,
	PB_DATA_TYPE.SINT32: 0,
	PB_DATA_TYPE.UINT32: 0,
	PB_DATA_TYPE.INT64: 0,
	PB_DATA_TYPE.SINT64: 0,
	PB_DATA_TYPE.UINT64: 0,
	PB_DATA_TYPE.BOOL: false,
	PB_DATA_TYPE.ENUM: 0,
	PB_DATA_TYPE.FIXED32: 0,
	PB_DATA_TYPE.SFIXED32: 0,
	PB_DATA_TYPE.FLOAT: 0.0,
	PB_DATA_TYPE.FIXED64: 0,
	PB_DATA_TYPE.SFIXED64: 0,
	PB_DATA_TYPE.DOUBLE: 0.0,
	PB_DATA_TYPE.STRING: "",
	PB_DATA_TYPE.BYTES: [],
	PB_DATA_TYPE.MESSAGE: null,
	PB_DATA_TYPE.MAP: []
}

enum PB_TYPE {
	VARINT = 0,
	FIX64 = 1,
	LENGTHDEL = 2,
	STARTGROUP = 3,
	ENDGROUP = 4,
	FIX32 = 5,
	UNDEFINED = 8
}

enum PB_RULE {
	OPTIONAL = 0,
	REQUIRED = 1,
	REPEATED = 2,
	RESERVED = 3
}

enum PB_SERVICE_STATE {
	FILLED = 0,
	UNFILLED = 1
}

class PBField:
	func _init(a_name : String, a_type : int, a_rule : int, a_tag : int, packed : bool, a_value = null):
		name = a_name
		type = a_type
		rule = a_rule
		tag = a_tag
		option_packed = packed
		value = a_value
		
	var name : String
	var type : int
	var rule : int
	var tag : int
	var option_packed : bool
	var value
	var is_map_field : bool = false
	var option_default : bool = false

class PBTypeTag:
	var ok : bool = false
	var type : int
	var tag : int
	var offset : int

class PBServiceField:
	var field : PBField
	var func_ref = null
	var state : int = PB_SERVICE_STATE.UNFILLED

class PBPacker:
	static func convert_signed(n : int) -> int:
		if n < -2147483648:
			return (n << 1) ^ (n >> 63)
		else:
			return (n << 1) ^ (n >> 31)

	static func deconvert_signed(n : int) -> int:
		if n & 0x01:
			return ~(n >> 1)
		else:
			return (n >> 1)

	static func pack_varint(value) -> PoolByteArray:
		var varint : PoolByteArray = PoolByteArray()
		if typeof(value) == TYPE_BOOL:
			if value:
				value = 1
			else:
				value = 0
		for _i in range(9):
			var b = value & 0x7F
			value >>= 7
			if value:
				varint.append(b | 0x80)
			else:
				varint.append(b)
				break
		if varint.size() == 9 && varint[8] == 0xFF:
			varint.append(0x01)
		return varint

	static func pack_bytes(value, count : int, data_type : int) -> PoolByteArray:
		var bytes : PoolByteArray = PoolByteArray()
		if data_type == PB_DATA_TYPE.FLOAT:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			spb.put_float(value)
			bytes = spb.get_data_array()
		elif data_type == PB_DATA_TYPE.DOUBLE:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			spb.put_double(value)
			bytes = spb.get_data_array()
		else:
			for _i in range(count):
				bytes.append(value & 0xFF)
				value >>= 8
		return bytes

	static func unpack_bytes(bytes : PoolByteArray, index : int, count : int, data_type : int):
		var value = 0
		if data_type == PB_DATA_TYPE.FLOAT:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			for i in range(index, count + index):
				spb.put_u8(bytes[i])
			spb.seek(0)
			value = spb.get_float()
		elif data_type == PB_DATA_TYPE.DOUBLE:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			for i in range(index, count + index):
				spb.put_u8(bytes[i])
			spb.seek(0)
			value = spb.get_double()
		else:
			for i in range(index + count - 1, index - 1, -1):
				value |= (bytes[i] & 0xFF)
				if i != index:
					value <<= 8
		return value

	static func unpack_varint(varint_bytes) -> int:
		var value : int = 0
		for i in range(varint_bytes.size() - 1, -1, -1):
			value |= varint_bytes[i] & 0x7F
			if i != 0:
				value <<= 7
		return value

	static func pack_type_tag(type : int, tag : int) -> PoolByteArray:
		return pack_varint((tag << 3) | type)

	static func isolate_varint(bytes : PoolByteArray, index : int) -> PoolByteArray:
		var result : PoolByteArray = PoolByteArray()
		for i in range(index, bytes.size()):
			result.append(bytes[i])
			if !(bytes[i] & 0x80):
				break
		return result

	static func unpack_type_tag(bytes : PoolByteArray, index : int) -> PBTypeTag:
		var varint_bytes : PoolByteArray = isolate_varint(bytes, index)
		var result : PBTypeTag = PBTypeTag.new()
		if varint_bytes.size() != 0:
			result.ok = true
			result.offset = varint_bytes.size()
			var unpacked : int = unpack_varint(varint_bytes)
			result.type = unpacked & 0x07
			result.tag = unpacked >> 3
		return result

	static func pack_length_delimeted(type : int, tag : int, bytes : PoolByteArray) -> PoolByteArray:
		var result : PoolByteArray = pack_type_tag(type, tag)
		result.append_array(pack_varint(bytes.size()))
		result.append_array(bytes)
		return result

	static func pb_type_from_data_type(data_type : int) -> int:
		if data_type == PB_DATA_TYPE.INT32 || data_type == PB_DATA_TYPE.SINT32 || data_type == PB_DATA_TYPE.UINT32 || data_type == PB_DATA_TYPE.INT64 || data_type == PB_DATA_TYPE.SINT64 || data_type == PB_DATA_TYPE.UINT64 || data_type == PB_DATA_TYPE.BOOL || data_type == PB_DATA_TYPE.ENUM:
			return PB_TYPE.VARINT
		elif data_type == PB_DATA_TYPE.FIXED32 || data_type == PB_DATA_TYPE.SFIXED32 || data_type == PB_DATA_TYPE.FLOAT:
			return PB_TYPE.FIX32
		elif data_type == PB_DATA_TYPE.FIXED64 || data_type == PB_DATA_TYPE.SFIXED64 || data_type == PB_DATA_TYPE.DOUBLE:
			return PB_TYPE.FIX64
		elif data_type == PB_DATA_TYPE.STRING || data_type == PB_DATA_TYPE.BYTES || data_type == PB_DATA_TYPE.MESSAGE || data_type == PB_DATA_TYPE.MAP:
			return PB_TYPE.LENGTHDEL
		else:
			return PB_TYPE.UNDEFINED

	static func pack_field(field : PBField) -> PoolByteArray:
		var type : int = pb_type_from_data_type(field.type)
		var type_copy : int = type
		if field.rule == PB_RULE.REPEATED && field.option_packed:
			type = PB_TYPE.LENGTHDEL
		var head : PoolByteArray = pack_type_tag(type, field.tag)
		var data : PoolByteArray = PoolByteArray()
		if type == PB_TYPE.VARINT:
			var value
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						value = convert_signed(v)
					else:
						value = v
					data.append_array(pack_varint(value))
				return data
			else:
				if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
					value = convert_signed(field.value)
				else:
					value = field.value
				data = pack_varint(value)
		elif type == PB_TYPE.FIX32:
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					data.append_array(pack_bytes(v, 4, field.type))
				return data
			else:
				data.append_array(pack_bytes(field.value, 4, field.type))
		elif type == PB_TYPE.FIX64:
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					data.append_array(pack_bytes(v, 8, field.type))
				return data
			else:
				data.append_array(pack_bytes(field.value, 8, field.type))
		elif type == PB_TYPE.LENGTHDEL:
			if field.rule == PB_RULE.REPEATED:
				if type_copy == PB_TYPE.VARINT:
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						var signed_value : int
						for v in field.value:
							signed_value = convert_signed(v)
							data.append_array(pack_varint(signed_value))
					else:
						for v in field.value:
							data.append_array(pack_varint(v))
					return pack_length_delimeted(type, field.tag, data)
				elif type_copy == PB_TYPE.FIX32:
					for v in field.value:
						data.append_array(pack_bytes(v, 4, field.type))
					return pack_length_delimeted(type, field.tag, data)
				elif type_copy == PB_TYPE.FIX64:
					for v in field.value:
						data.append_array(pack_bytes(v, 8, field.type))
					return pack_length_delimeted(type, field.tag, data)
				elif field.type == PB_DATA_TYPE.STRING:
					for v in field.value:
						var obj = v.to_utf8()
						data.append_array(pack_length_delimeted(type, field.tag, obj))
					return data
				elif field.type == PB_DATA_TYPE.BYTES:
					for v in field.value:
						data.append_array(pack_length_delimeted(type, field.tag, v))
					return data
				elif typeof(field.value[0]) == TYPE_OBJECT:
					for v in field.value:
						var obj : PoolByteArray = v.to_bytes()
						data.append_array(pack_length_delimeted(type, field.tag, obj))
					return data
			else:
				if field.type == PB_DATA_TYPE.STRING:
					var str_bytes : PoolByteArray = field.value.to_utf8()
					if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && str_bytes.size() > 0):
						data.append_array(str_bytes)
						return pack_length_delimeted(type, field.tag, data)
				if field.type == PB_DATA_TYPE.BYTES:
					if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && field.value.size() > 0):
						data.append_array(field.value)
						return pack_length_delimeted(type, field.tag, data)
				elif typeof(field.value) == TYPE_OBJECT:
					var obj : PoolByteArray = field.value.to_bytes()
					if obj.size() > 0:
						data.append_array(obj)
					return pack_length_delimeted(type, field.tag, data)
				else:
					pass
		if data.size() > 0:
			head.append_array(data)
			return head
		else:
			return data

	static func unpack_field(bytes : PoolByteArray, offset : int, field : PBField, type : int, message_func_ref) -> int:
		if field.rule == PB_RULE.REPEATED && type != PB_TYPE.LENGTHDEL && field.option_packed:
			var count = isolate_varint(bytes, offset)
			if count.size() > 0:
				offset += count.size()
				count = unpack_varint(count)
				if type == PB_TYPE.VARINT:
					var val
					var counter = offset + count
					while offset < counter:
						val = isolate_varint(bytes, offset)
						if val.size() > 0:
							offset += val.size()
							val = unpack_varint(val)
							if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
								val = deconvert_signed(val)
							elif field.type == PB_DATA_TYPE.BOOL:
								if val:
									val = true
								else:
									val = false
							field.value.append(val)
						else:
							return PB_ERR.REPEATED_COUNT_MISMATCH
					return offset
				elif type == PB_TYPE.FIX32 || type == PB_TYPE.FIX64:
					var type_size
					if type == PB_TYPE.FIX32:
						type_size = 4
					else:
						type_size = 8
					var val
					var counter = offset + count
					while offset < counter:
						if (offset + type_size) > bytes.size():
							return PB_ERR.REPEATED_COUNT_MISMATCH
						val = unpack_bytes(bytes, offset, type_size, field.type)
						offset += type_size
						field.value.append(val)
					return offset
			else:
				return PB_ERR.REPEATED_COUNT_NOT_FOUND
		else:
			if type == PB_TYPE.VARINT:
				var val = isolate_varint(bytes, offset)
				if val.size() > 0:
					offset += val.size()
					val = unpack_varint(val)
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						val = deconvert_signed(val)
					elif field.type == PB_DATA_TYPE.BOOL:
						if val:
							val = true
						else:
							val = false
					if field.rule == PB_RULE.REPEATED:
						field.value.append(val)
					else:
						field.value = val
				else:
					return PB_ERR.VARINT_NOT_FOUND
				return offset
			elif type == PB_TYPE.FIX32 || type == PB_TYPE.FIX64:
				var type_size
				if type == PB_TYPE.FIX32:
					type_size = 4
				else:
					type_size = 8
				var val
				if (offset + type_size) > bytes.size():
					return PB_ERR.REPEATED_COUNT_MISMATCH
				val = unpack_bytes(bytes, offset, type_size, field.type)
				offset += type_size
				if field.rule == PB_RULE.REPEATED:
					field.value.append(val)
				else:
					field.value = val
				return offset
			elif type == PB_TYPE.LENGTHDEL:
				var inner_size = isolate_varint(bytes, offset)
				if inner_size.size() > 0:
					offset += inner_size.size()
					inner_size = unpack_varint(inner_size)
					if inner_size >= 0:
						if inner_size + offset > bytes.size():
							return PB_ERR.LENGTHDEL_SIZE_MISMATCH
						if message_func_ref != null:
							var message = message_func_ref.call_func()
							if inner_size > 0:
								var sub_offset = message.from_bytes(bytes, offset, inner_size + offset)
								if sub_offset > 0:
									if sub_offset - offset >= inner_size:
										offset = sub_offset
										return offset
									else:
										return PB_ERR.LENGTHDEL_SIZE_MISMATCH
								return sub_offset
							else:
								return offset
						elif field.type == PB_DATA_TYPE.STRING:
							var str_bytes : PoolByteArray = PoolByteArray()
							for i in range(offset, inner_size + offset):
								str_bytes.append(bytes[i])
							if field.rule == PB_RULE.REPEATED:
								field.value.append(str_bytes.get_string_from_utf8())
							else:
								field.value = str_bytes.get_string_from_utf8()
							return offset + inner_size
						elif field.type == PB_DATA_TYPE.BYTES:
							var val_bytes : PoolByteArray = PoolByteArray()
							for i in range(offset, inner_size + offset):
								val_bytes.append(bytes[i])
							if field.rule == PB_RULE.REPEATED:
								field.value.append(val_bytes)
							else:
								field.value = val_bytes
							return offset + inner_size
					else:
						return PB_ERR.LENGTHDEL_SIZE_NOT_FOUND
				else:
					return PB_ERR.LENGTHDEL_SIZE_NOT_FOUND
		return PB_ERR.UNDEFINED_STATE

	static func unpack_message(data, bytes : PoolByteArray, offset : int, limit : int) -> int:
		while true:
			var tt : PBTypeTag = unpack_type_tag(bytes, offset)
			if tt.ok:
				offset += tt.offset
				if data.has(tt.tag):
					var service : PBServiceField = data[tt.tag]
					var type : int = pb_type_from_data_type(service.field.type)
					if type == tt.type || (tt.type == PB_TYPE.LENGTHDEL && service.field.rule == PB_RULE.REPEATED && service.field.option_packed):
						var res : int = unpack_field(bytes, offset, service.field, type, service.func_ref)
						if res > 0:
							service.state = PB_SERVICE_STATE.FILLED
							offset = res
							if offset == limit:
								return offset
							elif offset > limit:
								return PB_ERR.PACKAGE_SIZE_MISMATCH
						elif res < 0:
							return res
						else:
							break
			else:
				return offset
		return PB_ERR.UNDEFINED_STATE

	static func pack_message(data) -> PoolByteArray:
		var DEFAULT_VALUES
		if PROTO_VERSION == 2:
			DEFAULT_VALUES = DEFAULT_VALUES_2
		elif PROTO_VERSION == 3:
			DEFAULT_VALUES = DEFAULT_VALUES_3
		var result : PoolByteArray = PoolByteArray()
		var keys : Array = data.keys()
		keys.sort()
		for i in keys:
			if data[i].field.value != null:
				if data[i].state == PB_SERVICE_STATE.UNFILLED \
				&& !data[i].field.is_map_field \
				&& typeof(data[i].field.value) == typeof(DEFAULT_VALUES[data[i].field.type]) \
				&& data[i].field.value == DEFAULT_VALUES[data[i].field.type]:
					continue
				elif data[i].field.rule == PB_RULE.REPEATED && data[i].field.value.size() == 0:
					continue
				result.append_array(pack_field(data[i].field))
			elif data[i].field.rule == PB_RULE.REQUIRED:
				print("Error: required field is not filled: Tag:", data[i].field.tag)
				return PoolByteArray()
		return result

	static func check_required(data) -> bool:
		var keys : Array = data.keys()
		for i in keys:
			if data[i].field.rule == PB_RULE.REQUIRED && data[i].state == PB_SERVICE_STATE.UNFILLED:
				return false
		return true

	static func construct_map(key_values):
		var result = {}
		for kv in key_values:
			result[kv.get_key()] = kv.get_value()
		return result
	
	static func tabulate(text : String, nesting : int) -> String:
		var tab : String = ""
		for _i in range(nesting):
			tab += DEBUG_TAB
		return tab + text
	
	static func value_to_string(value, field : PBField, nesting : int) -> String:
		var result : String = ""
		var text : String
		if field.type == PB_DATA_TYPE.MESSAGE:
			result += "{"
			nesting += 1
			text = message_to_string(value.data, nesting)
			if text != "":
				result += "\n" + text
				nesting -= 1
				result += tabulate("}", nesting)
			else:
				nesting -= 1
				result += "}"
		elif field.type == PB_DATA_TYPE.BYTES:
			result += "<"
			for i in range(value.size()):
				result += String(value[i])
				if i != (value.size() - 1):
					result += ", "
			result += ">"
		elif field.type == PB_DATA_TYPE.STRING:
			result += "\"" + value + "\""
		elif field.type == PB_DATA_TYPE.ENUM:
			result += "ENUM::" + String(value)
		else:
			result += String(value)
		return result
	
	static func field_to_string(field : PBField, nesting : int) -> String:
		var result : String = tabulate(field.name + ": ", nesting)
		if field.type == PB_DATA_TYPE.MAP:
			if field.value.size() > 0:
				result += "(\n"
				nesting += 1
				for i in range(field.value.size()):
					var local_key_value = field.value[i].data[1].field
					result += tabulate(value_to_string(local_key_value.value, local_key_value, nesting), nesting) + ": "
					local_key_value = field.value[i].data[2].field
					result += value_to_string(local_key_value.value, local_key_value, nesting)
					if i != (field.value.size() - 1):
						result += ","
					result += "\n"
				nesting -= 1
				result += tabulate(")", nesting)
			else:
				result += "()"
		elif field.rule == PB_RULE.REPEATED:
			if field.value.size() > 0:
				result += "[\n"
				nesting += 1
				for i in range(field.value.size()):
					result += tabulate(String(i) + ": ", nesting)
					result += value_to_string(field.value[i], field, nesting)
					if i != (field.value.size() - 1):
						result += ","
					result += "\n"
				nesting -= 1
				result += tabulate("]", nesting)
			else:
				result += "[]"
		else:
			result += value_to_string(field.value, field, nesting)
		result += ";\n"
		return result
		
	static func message_to_string(data, nesting : int = 0) -> String:
		var DEFAULT_VALUES
		if PROTO_VERSION == 2:
			DEFAULT_VALUES = DEFAULT_VALUES_2
		elif PROTO_VERSION == 3:
			DEFAULT_VALUES = DEFAULT_VALUES_3
		var result : String = ""
		var keys : Array = data.keys()
		keys.sort()
		for i in keys:
			if data[i].field.value != null:
				if data[i].state == PB_SERVICE_STATE.UNFILLED \
				&& !data[i].field.is_map_field \
				&& typeof(data[i].field.value) == typeof(DEFAULT_VALUES[data[i].field.type]) \
				&& data[i].field.value == DEFAULT_VALUES[data[i].field.type]:
					continue
				elif data[i].field.rule == PB_RULE.REPEATED && data[i].field.value.size() == 0:
					continue
				result += field_to_string(data[i].field, nesting)
			elif data[i].field.rule == PB_RULE.REQUIRED:
				result += data[i].field.name + ": " + "error"
		return result



############### USER DATA BEGIN ################


class MovieParams:
	func _init():
		var service
		
		_viewBoxWidth = PBField.new("viewBoxWidth", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = _viewBoxWidth
		data[_viewBoxWidth.tag] = service
		
		_viewBoxHeight = PBField.new("viewBoxHeight", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = _viewBoxHeight
		data[_viewBoxHeight.tag] = service
		
		_fps = PBField.new("fps", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _fps
		data[_fps.tag] = service
		
		_frames = PBField.new("frames", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _frames
		data[_frames.tag] = service
		
	var data = {}
	
	var _viewBoxWidth: PBField
	func get_viewBoxWidth() -> float:
		return _viewBoxWidth.value
	func clear_viewBoxWidth() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_viewBoxWidth.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_viewBoxWidth(value : float) -> void:
		_viewBoxWidth.value = value
	
	var _viewBoxHeight: PBField
	func get_viewBoxHeight() -> float:
		return _viewBoxHeight.value
	func clear_viewBoxHeight() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_viewBoxHeight.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_viewBoxHeight(value : float) -> void:
		_viewBoxHeight.value = value
	
	var _fps: PBField
	func get_fps() -> int:
		return _fps.value
	func clear_fps() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_fps.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_fps(value : int) -> void:
		_fps.value = value
	
	var _frames: PBField
	func get_frames() -> int:
		return _frames.value
	func clear_frames() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_frames.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_frames(value : int) -> void:
		_frames.value = value
	
	func to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PoolByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PoolByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class SpriteEntity:
	func _init():
		var service
		
		_imageKey = PBField.new("imageKey", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = _imageKey
		data[_imageKey.tag] = service
		
		_frames = PBField.new("frames", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 2, true, [])
		service = PBServiceField.new()
		service.field = _frames
		service.func_ref = funcref(self, "add_frames")
		data[_frames.tag] = service
		
		_matteKey = PBField.new("matteKey", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = _matteKey
		data[_matteKey.tag] = service
		
	var data = {}
	
	var _imageKey: PBField
	func get_imageKey() -> String:
		return _imageKey.value
	func clear_imageKey() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_imageKey.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_imageKey(value : String) -> void:
		_imageKey.value = value
	
	var _frames: PBField
	func get_frames() -> Array:
		return _frames.value
	func clear_frames() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_frames.value = []
	func add_frames() -> FrameEntity:
		var element = FrameEntity.new()
		_frames.value.append(element)
		return element
	
	var _matteKey: PBField
	func get_matteKey() -> String:
		return _matteKey.value
	func clear_matteKey() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_matteKey.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_matteKey(value : String) -> void:
		_matteKey.value = value
	
	func to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PoolByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PoolByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class AudioEntity:
	func _init():
		var service
		
		_audioKey = PBField.new("audioKey", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = _audioKey
		data[_audioKey.tag] = service
		
		_startFrame = PBField.new("startFrame", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _startFrame
		data[_startFrame.tag] = service
		
		_endFrame = PBField.new("endFrame", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _endFrame
		data[_endFrame.tag] = service
		
		_startTime = PBField.new("startTime", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _startTime
		data[_startTime.tag] = service
		
		_totalTime = PBField.new("totalTime", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _totalTime
		data[_totalTime.tag] = service
		
	var data = {}
	
	var _audioKey: PBField
	func get_audioKey() -> String:
		return _audioKey.value
	func clear_audioKey() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_audioKey.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_audioKey(value : String) -> void:
		_audioKey.value = value
	
	var _startFrame: PBField
	func get_startFrame() -> int:
		return _startFrame.value
	func clear_startFrame() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_startFrame.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_startFrame(value : int) -> void:
		_startFrame.value = value
	
	var _endFrame: PBField
	func get_endFrame() -> int:
		return _endFrame.value
	func clear_endFrame() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_endFrame.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_endFrame(value : int) -> void:
		_endFrame.value = value
	
	var _startTime: PBField
	func get_startTime() -> int:
		return _startTime.value
	func clear_startTime() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_startTime.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_startTime(value : int) -> void:
		_startTime.value = value
	
	var _totalTime: PBField
	func get_totalTime() -> int:
		return _totalTime.value
	func clear_totalTime() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_totalTime.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_totalTime(value : int) -> void:
		_totalTime.value = value
	
	func to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PoolByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PoolByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class Layout:
	func _init():
		var service
		
		_x = PBField.new("x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = _x
		data[_x.tag] = service
		
		_y = PBField.new("y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = _y
		data[_y.tag] = service
		
		_width = PBField.new("width", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = _width
		data[_width.tag] = service
		
		_height = PBField.new("height", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = _height
		data[_height.tag] = service
		
	var data = {}
	
	var _x: PBField
	func get_x() -> float:
		return _x.value
	func clear_x() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_x(value : float) -> void:
		_x.value = value
	
	var _y: PBField
	func get_y() -> float:
		return _y.value
	func clear_y() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_y(value : float) -> void:
		_y.value = value
	
	var _width: PBField
	func get_width() -> float:
		return _width.value
	func clear_width() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_width.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_width(value : float) -> void:
		_width.value = value
	
	var _height: PBField
	func get_height() -> float:
		return _height.value
	func clear_height() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_height.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_height(value : float) -> void:
		_height.value = value
	
	func to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PoolByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PoolByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class SVGATransform:
	func _init():
		var service
		
		_a = PBField.new("a", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = _a
		data[_a.tag] = service
		
		_b = PBField.new("b", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = _b
		data[_b.tag] = service
		
		_c = PBField.new("c", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = _c
		data[_c.tag] = service
		
		_d = PBField.new("d", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = _d
		data[_d.tag] = service
		
		_tx = PBField.new("tx", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = _tx
		data[_tx.tag] = service
		
		_ty = PBField.new("ty", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = _ty
		data[_ty.tag] = service
		
	var data = {}
	
	var _a: PBField
	func get_a() -> float:
		return _a.value
	func clear_a() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_a.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_a(value : float) -> void:
		_a.value = value
	
	var _b: PBField
	func get_b() -> float:
		return _b.value
	func clear_b() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_b.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_b(value : float) -> void:
		_b.value = value
	
	var _c: PBField
	func get_c() -> float:
		return _c.value
	func clear_c() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_c.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_c(value : float) -> void:
		_c.value = value
	
	var _d: PBField
	func get_d() -> float:
		return _d.value
	func clear_d() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_d.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_d(value : float) -> void:
		_d.value = value
	
	var _tx: PBField
	func get_tx() -> float:
		return _tx.value
	func clear_tx() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_tx.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_tx(value : float) -> void:
		_tx.value = value
	
	var _ty: PBField
	func get_ty() -> float:
		return _ty.value
	func clear_ty() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_ty.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_ty(value : float) -> void:
		_ty.value = value
	
	func to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PoolByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PoolByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ShapeEntity:
	func _init():
		var service
		
		_type = PBField.new("type", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = _type
		data[_type.tag] = service
		
		_shape = PBField.new("shape", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _shape
		service.func_ref = funcref(self, "new_shape")
		data[_shape.tag] = service
		
		_rect = PBField.new("rect", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _rect
		service.func_ref = funcref(self, "new_rect")
		data[_rect.tag] = service
		
		_ellipse = PBField.new("ellipse", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _ellipse
		service.func_ref = funcref(self, "new_ellipse")
		data[_ellipse.tag] = service
		
		_styles = PBField.new("styles", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 10, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _styles
		service.func_ref = funcref(self, "new_styles")
		data[_styles.tag] = service
		
		_transform = PBField.new("transform", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 11, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _transform
		service.func_ref = funcref(self, "new_transform")
		data[_transform.tag] = service
		
	var data = {}
	
	var _type: PBField
	func get_type():
		return _type.value
	func clear_type() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_type.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_type(value) -> void:
		_type.value = value
	
	var _shape: PBField
	func has_shape() -> bool:
		return data[2].state == PB_SERVICE_STATE.FILLED
	func get_shape() -> ShapeEntity.ShapeArgs:
		return _shape.value
	func clear_shape() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_shape.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_shape() -> ShapeEntity.ShapeArgs:
		data[2].state = PB_SERVICE_STATE.FILLED
		_rect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_ellipse.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_shape.value = ShapeEntity.ShapeArgs.new()
		return _shape.value
	
	var _rect: PBField
	func has_rect() -> bool:
		return data[3].state == PB_SERVICE_STATE.FILLED
	func get_rect() -> ShapeEntity.RectArgs:
		return _rect.value
	func clear_rect() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_rect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_rect() -> ShapeEntity.RectArgs:
		_shape.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		data[3].state = PB_SERVICE_STATE.FILLED
		_ellipse.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_rect.value = ShapeEntity.RectArgs.new()
		return _rect.value
	
	var _ellipse: PBField
	func has_ellipse() -> bool:
		return data[4].state == PB_SERVICE_STATE.FILLED
	func get_ellipse() -> ShapeEntity.EllipseArgs:
		return _ellipse.value
	func clear_ellipse() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_ellipse.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_ellipse() -> ShapeEntity.EllipseArgs:
		_shape.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_rect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		data[4].state = PB_SERVICE_STATE.FILLED
		_ellipse.value = ShapeEntity.EllipseArgs.new()
		return _ellipse.value
	
	var _styles: PBField
	func get_styles() -> ShapeEntity.ShapeStyle:
		return _styles.value
	func clear_styles() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_styles.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_styles() -> ShapeEntity.ShapeStyle:
		_styles.value = ShapeEntity.ShapeStyle.new()
		return _styles.value
	
	var _transform: PBField
	func get_transform() -> SVGATransform:
		return _transform.value
	func clear_transform() -> void:
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_transform.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_transform() -> SVGATransform:
		_transform.value = SVGATransform.new()
		return _transform.value
	
	enum ShapeType {
		SHAPE = 0,
		RECT = 1,
		ELLIPSE = 2,
		KEEP = 3
	}
	
	class ShapeArgs:
		func _init():
			var service
			
			_d = PBField.new("d", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
			service = PBServiceField.new()
			service.field = _d
			data[_d.tag] = service
			
		var data = {}
		
		var _d: PBField
		func get_d() -> String:
			return _d.value
		func clear_d() -> void:
			data[1].state = PB_SERVICE_STATE.UNFILLED
			_d.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
		func set_d(value : String) -> void:
			_d.value = value
		
		func to_string() -> String:
			return PBPacker.message_to_string(data)
			
		func to_bytes() -> PoolByteArray:
			return PBPacker.pack_message(data)
			
		func from_bytes(bytes : PoolByteArray, offset : int = 0, limit : int = -1) -> int:
			var cur_limit = bytes.size()
			if limit != -1:
				cur_limit = limit
			var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
			if result == cur_limit:
				if PBPacker.check_required(data):
					if limit == -1:
						return PB_ERR.NO_ERRORS
				else:
					return PB_ERR.REQUIRED_FIELDS
			elif limit == -1 && result > 0:
				return PB_ERR.PARSE_INCOMPLETE
			return result
		
	class RectArgs:
		func _init():
			var service
			
			_x = PBField.new("x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
			service = PBServiceField.new()
			service.field = _x
			data[_x.tag] = service
			
			_y = PBField.new("y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
			service = PBServiceField.new()
			service.field = _y
			data[_y.tag] = service
			
			_width = PBField.new("width", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
			service = PBServiceField.new()
			service.field = _width
			data[_width.tag] = service
			
			_height = PBField.new("height", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
			service = PBServiceField.new()
			service.field = _height
			data[_height.tag] = service
			
			_cornerRadius = PBField.new("cornerRadius", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
			service = PBServiceField.new()
			service.field = _cornerRadius
			data[_cornerRadius.tag] = service
			
		var data = {}
		
		var _x: PBField
		func get_x() -> float:
			return _x.value
		func clear_x() -> void:
			data[1].state = PB_SERVICE_STATE.UNFILLED
			_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
		func set_x(value : float) -> void:
			_x.value = value
		
		var _y: PBField
		func get_y() -> float:
			return _y.value
		func clear_y() -> void:
			data[2].state = PB_SERVICE_STATE.UNFILLED
			_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
		func set_y(value : float) -> void:
			_y.value = value
		
		var _width: PBField
		func get_width() -> float:
			return _width.value
		func clear_width() -> void:
			data[3].state = PB_SERVICE_STATE.UNFILLED
			_width.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
		func set_width(value : float) -> void:
			_width.value = value
		
		var _height: PBField
		func get_height() -> float:
			return _height.value
		func clear_height() -> void:
			data[4].state = PB_SERVICE_STATE.UNFILLED
			_height.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
		func set_height(value : float) -> void:
			_height.value = value
		
		var _cornerRadius: PBField
		func get_cornerRadius() -> float:
			return _cornerRadius.value
		func clear_cornerRadius() -> void:
			data[5].state = PB_SERVICE_STATE.UNFILLED
			_cornerRadius.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
		func set_cornerRadius(value : float) -> void:
			_cornerRadius.value = value
		
		func to_string() -> String:
			return PBPacker.message_to_string(data)
			
		func to_bytes() -> PoolByteArray:
			return PBPacker.pack_message(data)
			
		func from_bytes(bytes : PoolByteArray, offset : int = 0, limit : int = -1) -> int:
			var cur_limit = bytes.size()
			if limit != -1:
				cur_limit = limit
			var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
			if result == cur_limit:
				if PBPacker.check_required(data):
					if limit == -1:
						return PB_ERR.NO_ERRORS
				else:
					return PB_ERR.REQUIRED_FIELDS
			elif limit == -1 && result > 0:
				return PB_ERR.PARSE_INCOMPLETE
			return result
		
	class EllipseArgs:
		func _init():
			var service
			
			_x = PBField.new("x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
			service = PBServiceField.new()
			service.field = _x
			data[_x.tag] = service
			
			_y = PBField.new("y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
			service = PBServiceField.new()
			service.field = _y
			data[_y.tag] = service
			
			_radiusX = PBField.new("radiusX", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
			service = PBServiceField.new()
			service.field = _radiusX
			data[_radiusX.tag] = service
			
			_radiusY = PBField.new("radiusY", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
			service = PBServiceField.new()
			service.field = _radiusY
			data[_radiusY.tag] = service
			
		var data = {}
		
		var _x: PBField
		func get_x() -> float:
			return _x.value
		func clear_x() -> void:
			data[1].state = PB_SERVICE_STATE.UNFILLED
			_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
		func set_x(value : float) -> void:
			_x.value = value
		
		var _y: PBField
		func get_y() -> float:
			return _y.value
		func clear_y() -> void:
			data[2].state = PB_SERVICE_STATE.UNFILLED
			_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
		func set_y(value : float) -> void:
			_y.value = value
		
		var _radiusX: PBField
		func get_radiusX() -> float:
			return _radiusX.value
		func clear_radiusX() -> void:
			data[3].state = PB_SERVICE_STATE.UNFILLED
			_radiusX.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
		func set_radiusX(value : float) -> void:
			_radiusX.value = value
		
		var _radiusY: PBField
		func get_radiusY() -> float:
			return _radiusY.value
		func clear_radiusY() -> void:
			data[4].state = PB_SERVICE_STATE.UNFILLED
			_radiusY.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
		func set_radiusY(value : float) -> void:
			_radiusY.value = value
		
		func to_string() -> String:
			return PBPacker.message_to_string(data)
			
		func to_bytes() -> PoolByteArray:
			return PBPacker.pack_message(data)
			
		func from_bytes(bytes : PoolByteArray, offset : int = 0, limit : int = -1) -> int:
			var cur_limit = bytes.size()
			if limit != -1:
				cur_limit = limit
			var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
			if result == cur_limit:
				if PBPacker.check_required(data):
					if limit == -1:
						return PB_ERR.NO_ERRORS
				else:
					return PB_ERR.REQUIRED_FIELDS
			elif limit == -1 && result > 0:
				return PB_ERR.PARSE_INCOMPLETE
			return result
		
	class ShapeStyle:
		func _init():
			var service
			
			_fill = PBField.new("fill", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
			service = PBServiceField.new()
			service.field = _fill
			service.func_ref = funcref(self, "new_fill")
			data[_fill.tag] = service
			
			_stroke = PBField.new("stroke", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
			service = PBServiceField.new()
			service.field = _stroke
			service.func_ref = funcref(self, "new_stroke")
			data[_stroke.tag] = service
			
			_strokeWidth = PBField.new("strokeWidth", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
			service = PBServiceField.new()
			service.field = _strokeWidth
			data[_strokeWidth.tag] = service
			
			_lineCap = PBField.new("lineCap", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
			service = PBServiceField.new()
			service.field = _lineCap
			data[_lineCap.tag] = service
			
			_lineJoin = PBField.new("lineJoin", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
			service = PBServiceField.new()
			service.field = _lineJoin
			data[_lineJoin.tag] = service
			
			_miterLimit = PBField.new("miterLimit", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
			service = PBServiceField.new()
			service.field = _miterLimit
			data[_miterLimit.tag] = service
			
			_lineDashI = PBField.new("lineDashI", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
			service = PBServiceField.new()
			service.field = _lineDashI
			data[_lineDashI.tag] = service
			
			_lineDashII = PBField.new("lineDashII", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
			service = PBServiceField.new()
			service.field = _lineDashII
			data[_lineDashII.tag] = service
			
			_lineDashIII = PBField.new("lineDashIII", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
			service = PBServiceField.new()
			service.field = _lineDashIII
			data[_lineDashIII.tag] = service
			
		var data = {}
		
		var _fill: PBField
		func get_fill() -> ShapeEntity.ShapeStyle.RGBAColor:
			return _fill.value
		func clear_fill() -> void:
			data[1].state = PB_SERVICE_STATE.UNFILLED
			_fill.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		func new_fill() -> ShapeEntity.ShapeStyle.RGBAColor:
			_fill.value = ShapeEntity.ShapeStyle.RGBAColor.new()
			return _fill.value
		
		var _stroke: PBField
		func get_stroke() -> ShapeEntity.ShapeStyle.RGBAColor:
			return _stroke.value
		func clear_stroke() -> void:
			data[2].state = PB_SERVICE_STATE.UNFILLED
			_stroke.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		func new_stroke() -> ShapeEntity.ShapeStyle.RGBAColor:
			_stroke.value = ShapeEntity.ShapeStyle.RGBAColor.new()
			return _stroke.value
		
		var _strokeWidth: PBField
		func get_strokeWidth() -> float:
			return _strokeWidth.value
		func clear_strokeWidth() -> void:
			data[3].state = PB_SERVICE_STATE.UNFILLED
			_strokeWidth.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
		func set_strokeWidth(value : float) -> void:
			_strokeWidth.value = value
		
		var _lineCap: PBField
		func get_lineCap():
			return _lineCap.value
		func clear_lineCap() -> void:
			data[4].state = PB_SERVICE_STATE.UNFILLED
			_lineCap.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
		func set_lineCap(value) -> void:
			_lineCap.value = value
		
		var _lineJoin: PBField
		func get_lineJoin():
			return _lineJoin.value
		func clear_lineJoin() -> void:
			data[5].state = PB_SERVICE_STATE.UNFILLED
			_lineJoin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
		func set_lineJoin(value) -> void:
			_lineJoin.value = value
		
		var _miterLimit: PBField
		func get_miterLimit() -> float:
			return _miterLimit.value
		func clear_miterLimit() -> void:
			data[6].state = PB_SERVICE_STATE.UNFILLED
			_miterLimit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
		func set_miterLimit(value : float) -> void:
			_miterLimit.value = value
		
		var _lineDashI: PBField
		func get_lineDashI() -> float:
			return _lineDashI.value
		func clear_lineDashI() -> void:
			data[7].state = PB_SERVICE_STATE.UNFILLED
			_lineDashI.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
		func set_lineDashI(value : float) -> void:
			_lineDashI.value = value
		
		var _lineDashII: PBField
		func get_lineDashII() -> float:
			return _lineDashII.value
		func clear_lineDashII() -> void:
			data[8].state = PB_SERVICE_STATE.UNFILLED
			_lineDashII.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
		func set_lineDashII(value : float) -> void:
			_lineDashII.value = value
		
		var _lineDashIII: PBField
		func get_lineDashIII() -> float:
			return _lineDashIII.value
		func clear_lineDashIII() -> void:
			data[9].state = PB_SERVICE_STATE.UNFILLED
			_lineDashIII.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
		func set_lineDashIII(value : float) -> void:
			_lineDashIII.value = value
		
		class RGBAColor:
			func _init():
				var service
				
				_r = PBField.new("r", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
				service = PBServiceField.new()
				service.field = _r
				data[_r.tag] = service
				
				_g = PBField.new("g", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
				service = PBServiceField.new()
				service.field = _g
				data[_g.tag] = service
				
				_b = PBField.new("b", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
				service = PBServiceField.new()
				service.field = _b
				data[_b.tag] = service
				
				_a = PBField.new("a", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
				service = PBServiceField.new()
				service.field = _a
				data[_a.tag] = service
				
			var data = {}
			
			var _r: PBField
			func get_r() -> float:
				return _r.value
			func clear_r() -> void:
				data[1].state = PB_SERVICE_STATE.UNFILLED
				_r.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
			func set_r(value : float) -> void:
				_r.value = value
			
			var _g: PBField
			func get_g() -> float:
				return _g.value
			func clear_g() -> void:
				data[2].state = PB_SERVICE_STATE.UNFILLED
				_g.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
			func set_g(value : float) -> void:
				_g.value = value
			
			var _b: PBField
			func get_b() -> float:
				return _b.value
			func clear_b() -> void:
				data[3].state = PB_SERVICE_STATE.UNFILLED
				_b.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
			func set_b(value : float) -> void:
				_b.value = value
			
			var _a: PBField
			func get_a() -> float:
				return _a.value
			func clear_a() -> void:
				data[4].state = PB_SERVICE_STATE.UNFILLED
				_a.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
			func set_a(value : float) -> void:
				_a.value = value
			
			func to_string() -> String:
				return PBPacker.message_to_string(data)
				
			func to_bytes() -> PoolByteArray:
				return PBPacker.pack_message(data)
				
			func from_bytes(bytes : PoolByteArray, offset : int = 0, limit : int = -1) -> int:
				var cur_limit = bytes.size()
				if limit != -1:
					cur_limit = limit
				var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
				if result == cur_limit:
					if PBPacker.check_required(data):
						if limit == -1:
							return PB_ERR.NO_ERRORS
					else:
						return PB_ERR.REQUIRED_FIELDS
				elif limit == -1 && result > 0:
					return PB_ERR.PARSE_INCOMPLETE
				return result
			
		enum LineCap {
			LineCap_BUTT = 0,
			LineCap_ROUND = 1,
			LineCap_SQUARE = 2
		}
		
		enum LineJoin {
			LineJoin_MITER = 0,
			LineJoin_ROUND = 1,
			LineJoin_BEVEL = 2
		}
		
		func to_string() -> String:
			return PBPacker.message_to_string(data)
			
		func to_bytes() -> PoolByteArray:
			return PBPacker.pack_message(data)
			
		func from_bytes(bytes : PoolByteArray, offset : int = 0, limit : int = -1) -> int:
			var cur_limit = bytes.size()
			if limit != -1:
				cur_limit = limit
			var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
			if result == cur_limit:
				if PBPacker.check_required(data):
					if limit == -1:
						return PB_ERR.NO_ERRORS
				else:
					return PB_ERR.REQUIRED_FIELDS
			elif limit == -1 && result > 0:
				return PB_ERR.PARSE_INCOMPLETE
			return result
		
	func to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PoolByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PoolByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class FrameEntity:
	func _init():
		var service
		
		_alpha = PBField.new("alpha", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = _alpha
		data[_alpha.tag] = service
		
		_layout = PBField.new("layout", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _layout
		service.func_ref = funcref(self, "new_layout")
		data[_layout.tag] = service
		
		_transform = PBField.new("transform", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _transform
		service.func_ref = funcref(self, "new_transform")
		data[_transform.tag] = service
		
		_clipPath = PBField.new("clipPath", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = _clipPath
		data[_clipPath.tag] = service
		
		_shapes = PBField.new("shapes", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 5, true, [])
		service = PBServiceField.new()
		service.field = _shapes
		service.func_ref = funcref(self, "add_shapes")
		data[_shapes.tag] = service
		
	var data = {}
	
	var _alpha: PBField
	func get_alpha() -> float:
		return _alpha.value
	func clear_alpha() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_alpha.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_alpha(value : float) -> void:
		_alpha.value = value
	
	var _layout: PBField
	func get_layout() -> Layout:
		return _layout.value
	func clear_layout() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_layout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_layout() -> Layout:
		_layout.value = Layout.new()
		return _layout.value
	
	var _transform: PBField
	func get_transform() -> SVGATransform:
		return _transform.value
	func clear_transform() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_transform.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_transform() -> SVGATransform:
		_transform.value = SVGATransform.new()
		return _transform.value
	
	var _clipPath: PBField
	func get_clipPath() -> String:
		return _clipPath.value
	func clear_clipPath() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_clipPath.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_clipPath(value : String) -> void:
		_clipPath.value = value
	
	var _shapes: PBField
	func get_shapes() -> Array:
		return _shapes.value
	func clear_shapes() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_shapes.value = []
	func add_shapes() -> ShapeEntity:
		var element = ShapeEntity.new()
		_shapes.value.append(element)
		return element
	
	func to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PoolByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PoolByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class MovieEntity:
	func _init():
		var service
		
		_version = PBField.new("version", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = _version
		data[_version.tag] = service
		
		_params = PBField.new("params", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _params
		service.func_ref = funcref(self, "new_params")
		data[_params.tag] = service
		
		_images = PBField.new("images", PB_DATA_TYPE.MAP, PB_RULE.REPEATED, 3, true, [])
		service = PBServiceField.new()
		service.field = _images
		service.func_ref = funcref(self, "add_empty_images")
		data[_images.tag] = service
		
		_sprites = PBField.new("sprites", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 4, true, [])
		service = PBServiceField.new()
		service.field = _sprites
		service.func_ref = funcref(self, "add_sprites")
		data[_sprites.tag] = service
		
		_audios = PBField.new("audios", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 5, true, [])
		service = PBServiceField.new()
		service.field = _audios
		service.func_ref = funcref(self, "add_audios")
		data[_audios.tag] = service
		
	var data = {}
	
	var _version: PBField
	func get_version() -> String:
		return _version.value
	func clear_version() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_version.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_version(value : String) -> void:
		_version.value = value
	
	var _params: PBField
	func get_params() -> MovieParams:
		return _params.value
	func clear_params() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_params.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_params() -> MovieParams:
		_params.value = MovieParams.new()
		return _params.value
	
	var _images: PBField
	func get_raw_images():
		return _images.value
	func get_images():
		return PBPacker.construct_map(_images.value)
	func clear_images():
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_images.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MAP]
	func add_empty_images() -> PoolByteArray:
		var element = MovieEntity.map_type_images.new()
		_images.value.append(element)
		return element
	func add_images(a_key, a_value) -> void:
		var idx = -1
		for i in range(_images.value.size()):
			if _images.value[i].get_key() == a_key:
				idx = i
				break
		var element = MovieEntity.map_type_images.new()
		element.set_key(a_key)
		element.set_value(a_value)
		if idx != -1:
			_images.value[idx] = element
		else:
			_images.value.append(element)
	
	var _sprites: PBField
	func get_sprites() -> Array:
		return _sprites.value
	func clear_sprites() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_sprites.value = []
	func add_sprites() -> SpriteEntity:
		var element = SpriteEntity.new()
		_sprites.value.append(element)
		return element
	
	var _audios: PBField
	func get_audios() -> Array:
		return _audios.value
	func clear_audios() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_audios.value = []
	func add_audios() -> AudioEntity:
		var element = AudioEntity.new()
		_audios.value.append(element)
		return element
	
	class map_type_images:
		func _init():
			var service
			
			_key = PBField.new("key", PB_DATA_TYPE.STRING, PB_RULE.REQUIRED, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
			_key.is_map_field = true
			service = PBServiceField.new()
			service.field = _key
			data[_key.tag] = service
			
			_value = PBField.new("value", PB_DATA_TYPE.BYTES, PB_RULE.REQUIRED, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES])
			_value.is_map_field = true
			service = PBServiceField.new()
			service.field = _value
			data[_value.tag] = service
			
		var data = {}
		
		var _key: PBField
		func get_key() -> String:
			return _key.value
		func clear_key() -> void:
			data[1].state = PB_SERVICE_STATE.UNFILLED
			_key.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
		func set_key(value : String) -> void:
			_key.value = value
		
		var _value: PBField
		func get_value() -> PoolByteArray:
			return _value.value
		func clear_value() -> void:
			data[2].state = PB_SERVICE_STATE.UNFILLED
			_value.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
		func set_value(value : PoolByteArray) -> void:
			_value.value = value
		
		func to_string() -> String:
			return PBPacker.message_to_string(data)
			
		func to_bytes() -> PoolByteArray:
			return PBPacker.pack_message(data)
			
		func from_bytes(bytes : PoolByteArray, offset : int = 0, limit : int = -1) -> int:
			var cur_limit = bytes.size()
			if limit != -1:
				cur_limit = limit
			var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
			if result == cur_limit:
				if PBPacker.check_required(data):
					if limit == -1:
						return PB_ERR.NO_ERRORS
				else:
					return PB_ERR.REQUIRED_FIELDS
			elif limit == -1 && result > 0:
				return PB_ERR.PARSE_INCOMPLETE
			return result
		
	func to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PoolByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PoolByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
################ USER DATA END #################
