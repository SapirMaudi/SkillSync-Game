#
# BSD 3-Clause License
#
# Copyright (c) 2018 - 2023, Oleg Malyavkin
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

const PROTO_VERSION = 3

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

	static func pack_varint(value) -> PackedByteArray:
		var varint : PackedByteArray = PackedByteArray()
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
		if varint.size() == 9 && (varint[8] & 0x80 != 0):
			varint.append(0x01)
		return varint

	static func pack_bytes(value, count : int, data_type : int) -> PackedByteArray:
		var bytes : PackedByteArray = PackedByteArray()
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

	static func unpack_bytes(bytes : PackedByteArray, index : int, count : int, data_type : int):
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

	static func pack_type_tag(type : int, tag : int) -> PackedByteArray:
		return pack_varint((tag << 3) | type)

	static func isolate_varint(bytes : PackedByteArray, index : int) -> PackedByteArray:
		var result : PackedByteArray = PackedByteArray()
		for i in range(index, bytes.size()):
			result.append(bytes[i])
			if !(bytes[i] & 0x80):
				break
		return result

	static func unpack_type_tag(bytes : PackedByteArray, index : int) -> PBTypeTag:
		var varint_bytes : PackedByteArray = isolate_varint(bytes, index)
		var result : PBTypeTag = PBTypeTag.new()
		if varint_bytes.size() != 0:
			result.ok = true
			result.offset = varint_bytes.size()
			var unpacked : int = unpack_varint(varint_bytes)
			result.type = unpacked & 0x07
			result.tag = unpacked >> 3
		return result

	static func pack_length_delimeted(type : int, tag : int, bytes : PackedByteArray) -> PackedByteArray:
		var result : PackedByteArray = pack_type_tag(type, tag)
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

	static func pack_field(field : PBField) -> PackedByteArray:
		var type : int = pb_type_from_data_type(field.type)
		var type_copy : int = type
		if field.rule == PB_RULE.REPEATED && field.option_packed:
			type = PB_TYPE.LENGTHDEL
		var head : PackedByteArray = pack_type_tag(type, field.tag)
		var data : PackedByteArray = PackedByteArray()
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
						var obj = v.to_utf8_buffer()
						data.append_array(pack_length_delimeted(type, field.tag, obj))
					return data
				elif field.type == PB_DATA_TYPE.BYTES:
					for v in field.value:
						data.append_array(pack_length_delimeted(type, field.tag, v))
					return data
				elif typeof(field.value[0]) == TYPE_OBJECT:
					for v in field.value:
						var obj : PackedByteArray = v.to_bytes()
						data.append_array(pack_length_delimeted(type, field.tag, obj))
					return data
			else:
				if field.type == PB_DATA_TYPE.STRING:
					var str_bytes : PackedByteArray = field.value.to_utf8_buffer()
					if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && str_bytes.size() > 0):
						data.append_array(str_bytes)
						return pack_length_delimeted(type, field.tag, data)
				if field.type == PB_DATA_TYPE.BYTES:
					if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && field.value.size() > 0):
						data.append_array(field.value)
						return pack_length_delimeted(type, field.tag, data)
				elif typeof(field.value) == TYPE_OBJECT:
					var obj : PackedByteArray = field.value.to_bytes()
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

	static func skip_unknown_field(bytes : PackedByteArray, offset : int, type : int) -> int:
		if type == PB_TYPE.VARINT:
			return offset + isolate_varint(bytes, offset).size()
		if type == PB_TYPE.FIX64:
			return offset + 8
		if type == PB_TYPE.LENGTHDEL:
			var length_bytes : PackedByteArray = isolate_varint(bytes, offset)
			var length : int = unpack_varint(length_bytes)
			return offset + length_bytes.size() + length
		if type == PB_TYPE.FIX32:
			return offset + 4
		return PB_ERR.UNDEFINED_STATE

	static func unpack_field(bytes : PackedByteArray, offset : int, field : PBField, type : int, message_func_ref) -> int:
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
							var message = message_func_ref.call()
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
							var str_bytes : PackedByteArray = PackedByteArray()
							for i in range(offset, inner_size + offset):
								str_bytes.append(bytes[i])
							if field.rule == PB_RULE.REPEATED:
								field.value.append(str_bytes.get_string_from_utf8())
							else:
								field.value = str_bytes.get_string_from_utf8()
							return offset + inner_size
						elif field.type == PB_DATA_TYPE.BYTES:
							var val_bytes : PackedByteArray = PackedByteArray()
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

	static func unpack_message(data, bytes : PackedByteArray, offset : int, limit : int) -> int:
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
					var res : int = skip_unknown_field(bytes, offset, tt.type)
					if res > 0:
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

	static func pack_message(data) -> PackedByteArray:
		var DEFAULT_VALUES
		if PROTO_VERSION == 2:
			DEFAULT_VALUES = DEFAULT_VALUES_2
		elif PROTO_VERSION == 3:
			DEFAULT_VALUES = DEFAULT_VALUES_3
		var result : PackedByteArray = PackedByteArray()
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
				return PackedByteArray()
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
				result += str(value[i])
				if i != (value.size() - 1):
					result += ", "
			result += ">"
		elif field.type == PB_DATA_TYPE.STRING:
			result += "\"" + value + "\""
		elif field.type == PB_DATA_TYPE.ENUM:
			result += "ENUM::" + str(value)
		else:
			result += str(value)
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
					result += tabulate(str(i) + ": ", nesting)
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


class ChatMessage:
	func _init():
		var service
		
		__msg = PBField.new("msg", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __msg
		data[__msg.tag] = service
		
	var data = {}
	
	var __msg: PBField
	func has_msg() -> bool:
		if __msg.value != null:
			return true
		return false
	func get_msg() -> String:
		return __msg.value
	func clear_msg() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__msg.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_msg(value : String) -> void:
		__msg.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class IdMessage:
	func _init():
		var service
		
		__id = PBField.new("id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __id
		data[__id.tag] = service
		
	var data = {}
	
	var __id: PBField
	func has_id() -> bool:
		if __id.value != null:
			return true
		return false
	func get_id() -> int:
		return __id.value
	func clear_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_id(value : int) -> void:
		__id.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class LoginRequestMessage:
	func _init():
		var service
		
		__email = PBField.new("email", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __email
		data[__email.tag] = service
		
		__password = PBField.new("password", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __password
		data[__password.tag] = service
		
	var data = {}
	
	var __email: PBField
	func has_email() -> bool:
		if __email.value != null:
			return true
		return false
	func get_email() -> String:
		return __email.value
	func clear_email() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__email.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_email(value : String) -> void:
		__email.value = value
	
	var __password: PBField
	func has_password() -> bool:
		if __password.value != null:
			return true
		return false
	func get_password() -> String:
		return __password.value
	func clear_password() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__password.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_password(value : String) -> void:
		__password.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class RegisterRequestMessage:
	func _init():
		var service
		
		__nickname = PBField.new("nickname", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __nickname
		data[__nickname.tag] = service
		
		__email = PBField.new("email", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __email
		data[__email.tag] = service
		
		__password = PBField.new("password", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __password
		data[__password.tag] = service
		
	var data = {}
	
	var __nickname: PBField
	func has_nickname() -> bool:
		if __nickname.value != null:
			return true
		return false
	func get_nickname() -> String:
		return __nickname.value
	func clear_nickname() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__nickname.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_nickname(value : String) -> void:
		__nickname.value = value
	
	var __email: PBField
	func has_email() -> bool:
		if __email.value != null:
			return true
		return false
	func get_email() -> String:
		return __email.value
	func clear_email() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__email.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_email(value : String) -> void:
		__email.value = value
	
	var __password: PBField
	func has_password() -> bool:
		if __password.value != null:
			return true
		return false
	func get_password() -> String:
		return __password.value
	func clear_password() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__password.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_password(value : String) -> void:
		__password.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class OkResponseMessage:
	func _init():
		var service
		
	var data = {}
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class ErrorResponseMessage:
	func _init():
		var service
		
		__reason = PBField.new("reason", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __reason
		data[__reason.tag] = service
		
	var data = {}
	
	var __reason: PBField
	func has_reason() -> bool:
		if __reason.value != null:
			return true
		return false
	func get_reason() -> String:
		return __reason.value
	func clear_reason() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__reason.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_reason(value : String) -> void:
		__reason.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class RequestGeneralInfoMessage:
	func _init():
		var service
		
		__info = PBField.new("info", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __info
		data[__info.tag] = service
		
	var data = {}
	
	var __info: PBField
	func has_info() -> bool:
		if __info.value != null:
			return true
		return false
	func get_info() -> String:
		return __info.value
	func clear_info() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_info(value : String) -> void:
		__info.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class ResponseUserStatsMessage:
	func _init():
		var service
		
		__kills = PBField.new("kills", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __kills
		data[__kills.tag] = service
		
		__deaths = PBField.new("deaths", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __deaths
		data[__deaths.tag] = service
		
		__wins = PBField.new("wins", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __wins
		data[__wins.tag] = service
		
		__losses = PBField.new("losses", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __losses
		data[__losses.tag] = service
		
		__flags_captured = PBField.new("flags_captured", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __flags_captured
		data[__flags_captured.tag] = service
		
	var data = {}
	
	var __kills: PBField
	func has_kills() -> bool:
		if __kills.value != null:
			return true
		return false
	func get_kills() -> int:
		return __kills.value
	func clear_kills() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__kills.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_kills(value : int) -> void:
		__kills.value = value
	
	var __deaths: PBField
	func has_deaths() -> bool:
		if __deaths.value != null:
			return true
		return false
	func get_deaths() -> int:
		return __deaths.value
	func clear_deaths() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__deaths.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_deaths(value : int) -> void:
		__deaths.value = value
	
	var __wins: PBField
	func has_wins() -> bool:
		if __wins.value != null:
			return true
		return false
	func get_wins() -> int:
		return __wins.value
	func clear_wins() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__wins.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_wins(value : int) -> void:
		__wins.value = value
	
	var __losses: PBField
	func has_losses() -> bool:
		if __losses.value != null:
			return true
		return false
	func get_losses() -> int:
		return __losses.value
	func clear_losses() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__losses.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_losses(value : int) -> void:
		__losses.value = value
	
	var __flags_captured: PBField
	func has_flags_captured() -> bool:
		if __flags_captured.value != null:
			return true
		return false
	func get_flags_captured() -> int:
		return __flags_captured.value
	func clear_flags_captured() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__flags_captured.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_flags_captured(value : int) -> void:
		__flags_captured.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class ResponseUserNameMessage:
	func _init():
		var service
		
		__nickname = PBField.new("nickname", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __nickname
		data[__nickname.tag] = service
		
	var data = {}
	
	var __nickname: PBField
	func has_nickname() -> bool:
		if __nickname.value != null:
			return true
		return false
	func get_nickname() -> String:
		return __nickname.value
	func clear_nickname() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__nickname.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_nickname(value : String) -> void:
		__nickname.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class ResponseUserSkinMessage:
	func _init():
		var service
		
		__skin_id = PBField.new("skin_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __skin_id
		data[__skin_id.tag] = service
		
	var data = {}
	
	var __skin_id: PBField
	func has_skin_id() -> bool:
		if __skin_id.value != null:
			return true
		return false
	func get_skin_id() -> int:
		return __skin_id.value
	func clear_skin_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__skin_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_skin_id(value : int) -> void:
		__skin_id.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class RequestUpdateUserSkinMessage:
	func _init():
		var service
		
		__skin_id = PBField.new("skin_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __skin_id
		data[__skin_id.tag] = service
		
	var data = {}
	
	var __skin_id: PBField
	func has_skin_id() -> bool:
		if __skin_id.value != null:
			return true
		return false
	func get_skin_id() -> int:
		return __skin_id.value
	func clear_skin_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__skin_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_skin_id(value : int) -> void:
		__skin_id.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class RequestEnterQueueMessage:
	func _init():
		var service
		
	var data = {}
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class RequestLeaveQueueMessage:
	func _init():
		var service
		
	var data = {}
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class QueueJoinedMessage:
	func _init():
		var service
		
		__position = PBField.new("position", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __position
		data[__position.tag] = service
		
		__size = PBField.new("size", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __size
		data[__size.tag] = service
		
	var data = {}
	
	var __position: PBField
	func has_position() -> bool:
		if __position.value != null:
			return true
		return false
	func get_position() -> int:
		return __position.value
	func clear_position() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__position.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_position(value : int) -> void:
		__position.value = value
	
	var __size: PBField
	func has_size() -> bool:
		if __size.value != null:
			return true
		return false
	func get_size() -> int:
		return __size.value
	func clear_size() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__size.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_size(value : int) -> void:
		__size.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class QueueLeftMessage:
	func _init():
		var service
		
	var data = {}
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class MatchFoundMessage:
	func _init():
		var service
		
		__game_id = PBField.new("game_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __game_id
		data[__game_id.tag] = service
		
		__team = PBField.new("team", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __team
		data[__team.tag] = service
		
		var __team_ids_default: Array[int] = []
		__team_ids = PBField.new("team_ids", PB_DATA_TYPE.UINT64, PB_RULE.REPEATED, 3, true, __team_ids_default)
		service = PBServiceField.new()
		service.field = __team_ids
		data[__team_ids.tag] = service
		
		var __enemy_ids_default: Array[int] = []
		__enemy_ids = PBField.new("enemy_ids", PB_DATA_TYPE.UINT64, PB_RULE.REPEATED, 4, true, __enemy_ids_default)
		service = PBServiceField.new()
		service.field = __enemy_ids
		data[__enemy_ids.tag] = service
		
	var data = {}
	
	var __game_id: PBField
	func has_game_id() -> bool:
		if __game_id.value != null:
			return true
		return false
	func get_game_id() -> int:
		return __game_id.value
	func clear_game_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__game_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_game_id(value : int) -> void:
		__game_id.value = value
	
	var __team: PBField
	func has_team() -> bool:
		if __team.value != null:
			return true
		return false
	func get_team() -> int:
		return __team.value
	func clear_team() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__team.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_team(value : int) -> void:
		__team.value = value
	
	var __team_ids: PBField
	func get_team_ids() -> Array[int]:
		return __team_ids.value
	func clear_team_ids() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__team_ids.value.clear()
	func add_team_ids(value : int) -> void:
		__team_ids.value.append(value)
	
	var __enemy_ids: PBField
	func get_enemy_ids() -> Array[int]:
		return __enemy_ids.value
	func clear_enemy_ids() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__enemy_ids.value.clear()
	func add_enemy_ids(value : int) -> void:
		__enemy_ids.value.append(value)
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class SpawnPlayerMessage:
	func _init():
		var service
		
		__game_id = PBField.new("game_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __game_id
		data[__game_id.tag] = service
		
		__player_id = PBField.new("player_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __player_id
		data[__player_id.tag] = service
		
		__team = PBField.new("team", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __team
		data[__team.tag] = service
		
		__slot = PBField.new("slot", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __slot
		data[__slot.tag] = service
		
		__x = PBField.new("x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __x
		data[__x.tag] = service
		
		__y = PBField.new("y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __y
		data[__y.tag] = service
		
		__nickname = PBField.new("nickname", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __nickname
		data[__nickname.tag] = service
		
		__skin_id = PBField.new("skin_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __skin_id
		data[__skin_id.tag] = service
		
		__current_hp = PBField.new("current_hp", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __current_hp
		data[__current_hp.tag] = service
		
		__max_hp = PBField.new("max_hp", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 10, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __max_hp
		data[__max_hp.tag] = service
		
		__aim_x = PBField.new("aim_x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 11, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __aim_x
		data[__aim_x.tag] = service
		
		__aim_y = PBField.new("aim_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 12, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __aim_y
		data[__aim_y.tag] = service
		
	var data = {}
	
	var __game_id: PBField
	func has_game_id() -> bool:
		if __game_id.value != null:
			return true
		return false
	func get_game_id() -> int:
		return __game_id.value
	func clear_game_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__game_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_game_id(value : int) -> void:
		__game_id.value = value
	
	var __player_id: PBField
	func has_player_id() -> bool:
		if __player_id.value != null:
			return true
		return false
	func get_player_id() -> int:
		return __player_id.value
	func clear_player_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__player_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_player_id(value : int) -> void:
		__player_id.value = value
	
	var __team: PBField
	func has_team() -> bool:
		if __team.value != null:
			return true
		return false
	func get_team() -> int:
		return __team.value
	func clear_team() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__team.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_team(value : int) -> void:
		__team.value = value
	
	var __slot: PBField
	func has_slot() -> bool:
		if __slot.value != null:
			return true
		return false
	func get_slot() -> int:
		return __slot.value
	func clear_slot() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__slot.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_slot(value : int) -> void:
		__slot.value = value
	
	var __x: PBField
	func has_x() -> bool:
		if __x.value != null:
			return true
		return false
	func get_x() -> float:
		return __x.value
	func clear_x() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_x(value : float) -> void:
		__x.value = value
	
	var __y: PBField
	func has_y() -> bool:
		if __y.value != null:
			return true
		return false
	func get_y() -> float:
		return __y.value
	func clear_y() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_y(value : float) -> void:
		__y.value = value
	
	var __nickname: PBField
	func has_nickname() -> bool:
		if __nickname.value != null:
			return true
		return false
	func get_nickname() -> String:
		return __nickname.value
	func clear_nickname() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__nickname.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_nickname(value : String) -> void:
		__nickname.value = value
	
	var __skin_id: PBField
	func has_skin_id() -> bool:
		if __skin_id.value != null:
			return true
		return false
	func get_skin_id() -> int:
		return __skin_id.value
	func clear_skin_id() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__skin_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_skin_id(value : int) -> void:
		__skin_id.value = value
	
	var __current_hp: PBField
	func has_current_hp() -> bool:
		if __current_hp.value != null:
			return true
		return false
	func get_current_hp() -> int:
		return __current_hp.value
	func clear_current_hp() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__current_hp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_current_hp(value : int) -> void:
		__current_hp.value = value
	
	var __max_hp: PBField
	func has_max_hp() -> bool:
		if __max_hp.value != null:
			return true
		return false
	func get_max_hp() -> int:
		return __max_hp.value
	func clear_max_hp() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__max_hp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_max_hp(value : int) -> void:
		__max_hp.value = value
	
	var __aim_x: PBField
	func has_aim_x() -> bool:
		if __aim_x.value != null:
			return true
		return false
	func get_aim_x() -> float:
		return __aim_x.value
	func clear_aim_x() -> void:
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__aim_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_aim_x(value : float) -> void:
		__aim_x.value = value
	
	var __aim_y: PBField
	func has_aim_y() -> bool:
		if __aim_y.value != null:
			return true
		return false
	func get_aim_y() -> float:
		return __aim_y.value
	func clear_aim_y() -> void:
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__aim_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_aim_y(value : float) -> void:
		__aim_y.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class DespawnPlayerMessage:
	func _init():
		var service
		
		__game_id = PBField.new("game_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __game_id
		data[__game_id.tag] = service
		
		__player_id = PBField.new("player_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __player_id
		data[__player_id.tag] = service
		
	var data = {}
	
	var __game_id: PBField
	func has_game_id() -> bool:
		if __game_id.value != null:
			return true
		return false
	func get_game_id() -> int:
		return __game_id.value
	func clear_game_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__game_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_game_id(value : int) -> void:
		__game_id.value = value
	
	var __player_id: PBField
	func has_player_id() -> bool:
		if __player_id.value != null:
			return true
		return false
	func get_player_id() -> int:
		return __player_id.value
	func clear_player_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__player_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_player_id(value : int) -> void:
		__player_id.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class MovementInputMessage:
	func _init():
		var service
		
		__game_id = PBField.new("game_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __game_id
		data[__game_id.tag] = service
		
		__x = PBField.new("x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __x
		data[__x.tag] = service
		
		__y = PBField.new("y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __y
		data[__y.tag] = service
		
	var data = {}
	
	var __game_id: PBField
	func has_game_id() -> bool:
		if __game_id.value != null:
			return true
		return false
	func get_game_id() -> int:
		return __game_id.value
	func clear_game_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__game_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_game_id(value : int) -> void:
		__game_id.value = value
	
	var __x: PBField
	func has_x() -> bool:
		if __x.value != null:
			return true
		return false
	func get_x() -> float:
		return __x.value
	func clear_x() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_x(value : float) -> void:
		__x.value = value
	
	var __y: PBField
	func has_y() -> bool:
		if __y.value != null:
			return true
		return false
	func get_y() -> float:
		return __y.value
	func clear_y() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_y(value : float) -> void:
		__y.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class PlayerMovedMessage:
	func _init():
		var service
		
		__game_id = PBField.new("game_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __game_id
		data[__game_id.tag] = service
		
		__player_id = PBField.new("player_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __player_id
		data[__player_id.tag] = service
		
		__x = PBField.new("x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __x
		data[__x.tag] = service
		
		__y = PBField.new("y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __y
		data[__y.tag] = service
		
	var data = {}
	
	var __game_id: PBField
	func has_game_id() -> bool:
		if __game_id.value != null:
			return true
		return false
	func get_game_id() -> int:
		return __game_id.value
	func clear_game_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__game_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_game_id(value : int) -> void:
		__game_id.value = value
	
	var __player_id: PBField
	func has_player_id() -> bool:
		if __player_id.value != null:
			return true
		return false
	func get_player_id() -> int:
		return __player_id.value
	func clear_player_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__player_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_player_id(value : int) -> void:
		__player_id.value = value
	
	var __x: PBField
	func has_x() -> bool:
		if __x.value != null:
			return true
		return false
	func get_x() -> float:
		return __x.value
	func clear_x() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_x(value : float) -> void:
		__x.value = value
	
	var __y: PBField
	func has_y() -> bool:
		if __y.value != null:
			return true
		return false
	func get_y() -> float:
		return __y.value
	func clear_y() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_y(value : float) -> void:
		__y.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class PlayerHealthUpdatedMessage:
	func _init():
		var service
		
		__game_id = PBField.new("game_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __game_id
		data[__game_id.tag] = service
		
		__player_id = PBField.new("player_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __player_id
		data[__player_id.tag] = service
		
		__current_hp = PBField.new("current_hp", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __current_hp
		data[__current_hp.tag] = service
		
		__max_hp = PBField.new("max_hp", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __max_hp
		data[__max_hp.tag] = service
		
	var data = {}
	
	var __game_id: PBField
	func has_game_id() -> bool:
		if __game_id.value != null:
			return true
		return false
	func get_game_id() -> int:
		return __game_id.value
	func clear_game_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__game_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_game_id(value : int) -> void:
		__game_id.value = value
	
	var __player_id: PBField
	func has_player_id() -> bool:
		if __player_id.value != null:
			return true
		return false
	func get_player_id() -> int:
		return __player_id.value
	func clear_player_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__player_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_player_id(value : int) -> void:
		__player_id.value = value
	
	var __current_hp: PBField
	func has_current_hp() -> bool:
		if __current_hp.value != null:
			return true
		return false
	func get_current_hp() -> int:
		return __current_hp.value
	func clear_current_hp() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__current_hp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_current_hp(value : int) -> void:
		__current_hp.value = value
	
	var __max_hp: PBField
	func has_max_hp() -> bool:
		if __max_hp.value != null:
			return true
		return false
	func get_max_hp() -> int:
		return __max_hp.value
	func clear_max_hp() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__max_hp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_max_hp(value : int) -> void:
		__max_hp.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class SpawnFlagMessage:
	func _init():
		var service
		
		__game_id = PBField.new("game_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __game_id
		data[__game_id.tag] = service
		
		__team = PBField.new("team", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __team
		data[__team.tag] = service
		
		__x = PBField.new("x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __x
		data[__x.tag] = service
		
		__y = PBField.new("y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __y
		data[__y.tag] = service
		
		__status = PBField.new("status", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __status
		data[__status.tag] = service
		
		__carrier_player_id = PBField.new("carrier_player_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __carrier_player_id
		data[__carrier_player_id.tag] = service
		
	var data = {}
	
	var __game_id: PBField
	func has_game_id() -> bool:
		if __game_id.value != null:
			return true
		return false
	func get_game_id() -> int:
		return __game_id.value
	func clear_game_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__game_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_game_id(value : int) -> void:
		__game_id.value = value
	
	var __team: PBField
	func has_team() -> bool:
		if __team.value != null:
			return true
		return false
	func get_team() -> int:
		return __team.value
	func clear_team() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__team.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_team(value : int) -> void:
		__team.value = value
	
	var __x: PBField
	func has_x() -> bool:
		if __x.value != null:
			return true
		return false
	func get_x() -> float:
		return __x.value
	func clear_x() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_x(value : float) -> void:
		__x.value = value
	
	var __y: PBField
	func has_y() -> bool:
		if __y.value != null:
			return true
		return false
	func get_y() -> float:
		return __y.value
	func clear_y() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_y(value : float) -> void:
		__y.value = value
	
	var __status: PBField
	func has_status() -> bool:
		if __status.value != null:
			return true
		return false
	func get_status() -> int:
		return __status.value
	func clear_status() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__status.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_status(value : int) -> void:
		__status.value = value
	
	var __carrier_player_id: PBField
	func has_carrier_player_id() -> bool:
		if __carrier_player_id.value != null:
			return true
		return false
	func get_carrier_player_id() -> int:
		return __carrier_player_id.value
	func clear_carrier_player_id() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__carrier_player_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_carrier_player_id(value : int) -> void:
		__carrier_player_id.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class FlagStateUpdatedMessage:
	func _init():
		var service
		
		__game_id = PBField.new("game_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __game_id
		data[__game_id.tag] = service
		
		__team = PBField.new("team", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __team
		data[__team.tag] = service
		
		__x = PBField.new("x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __x
		data[__x.tag] = service
		
		__y = PBField.new("y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __y
		data[__y.tag] = service
		
		__status = PBField.new("status", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __status
		data[__status.tag] = service
		
		__carrier_player_id = PBField.new("carrier_player_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __carrier_player_id
		data[__carrier_player_id.tag] = service
		
	var data = {}
	
	var __game_id: PBField
	func has_game_id() -> bool:
		if __game_id.value != null:
			return true
		return false
	func get_game_id() -> int:
		return __game_id.value
	func clear_game_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__game_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_game_id(value : int) -> void:
		__game_id.value = value
	
	var __team: PBField
	func has_team() -> bool:
		if __team.value != null:
			return true
		return false
	func get_team() -> int:
		return __team.value
	func clear_team() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__team.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_team(value : int) -> void:
		__team.value = value
	
	var __x: PBField
	func has_x() -> bool:
		if __x.value != null:
			return true
		return false
	func get_x() -> float:
		return __x.value
	func clear_x() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_x(value : float) -> void:
		__x.value = value
	
	var __y: PBField
	func has_y() -> bool:
		if __y.value != null:
			return true
		return false
	func get_y() -> float:
		return __y.value
	func clear_y() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_y(value : float) -> void:
		__y.value = value
	
	var __status: PBField
	func has_status() -> bool:
		if __status.value != null:
			return true
		return false
	func get_status() -> int:
		return __status.value
	func clear_status() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__status.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_status(value : int) -> void:
		__status.value = value
	
	var __carrier_player_id: PBField
	func has_carrier_player_id() -> bool:
		if __carrier_player_id.value != null:
			return true
		return false
	func get_carrier_player_id() -> int:
		return __carrier_player_id.value
	func clear_carrier_player_id() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__carrier_player_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_carrier_player_id(value : int) -> void:
		__carrier_player_id.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class ScoreUpdatedMessage:
	func _init():
		var service
		
		__game_id = PBField.new("game_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __game_id
		data[__game_id.tag] = service
		
		__red_score = PBField.new("red_score", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __red_score
		data[__red_score.tag] = service
		
		__blue_score = PBField.new("blue_score", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __blue_score
		data[__blue_score.tag] = service
		
	var data = {}
	
	var __game_id: PBField
	func has_game_id() -> bool:
		if __game_id.value != null:
			return true
		return false
	func get_game_id() -> int:
		return __game_id.value
	func clear_game_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__game_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_game_id(value : int) -> void:
		__game_id.value = value
	
	var __red_score: PBField
	func has_red_score() -> bool:
		if __red_score.value != null:
			return true
		return false
	func get_red_score() -> int:
		return __red_score.value
	func clear_red_score() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__red_score.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_red_score(value : int) -> void:
		__red_score.value = value
	
	var __blue_score: PBField
	func has_blue_score() -> bool:
		if __blue_score.value != null:
			return true
		return false
	func get_blue_score() -> int:
		return __blue_score.value
	func clear_blue_score() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__blue_score.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_blue_score(value : int) -> void:
		__blue_score.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class GameTimeUpdatedMessage:
	func _init():
		var service
		
		__game_id = PBField.new("game_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __game_id
		data[__game_id.tag] = service
		
		__remaining_seconds = PBField.new("remaining_seconds", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __remaining_seconds
		data[__remaining_seconds.tag] = service
		
		__duration_seconds = PBField.new("duration_seconds", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __duration_seconds
		data[__duration_seconds.tag] = service
		
		__is_running = PBField.new("is_running", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __is_running
		data[__is_running.tag] = service
		
	var data = {}
	
	var __game_id: PBField
	func has_game_id() -> bool:
		if __game_id.value != null:
			return true
		return false
	func get_game_id() -> int:
		return __game_id.value
	func clear_game_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__game_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_game_id(value : int) -> void:
		__game_id.value = value
	
	var __remaining_seconds: PBField
	func has_remaining_seconds() -> bool:
		if __remaining_seconds.value != null:
			return true
		return false
	func get_remaining_seconds() -> int:
		return __remaining_seconds.value
	func clear_remaining_seconds() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__remaining_seconds.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_remaining_seconds(value : int) -> void:
		__remaining_seconds.value = value
	
	var __duration_seconds: PBField
	func has_duration_seconds() -> bool:
		if __duration_seconds.value != null:
			return true
		return false
	func get_duration_seconds() -> int:
		return __duration_seconds.value
	func clear_duration_seconds() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__duration_seconds.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_duration_seconds(value : int) -> void:
		__duration_seconds.value = value
	
	var __is_running: PBField
	func has_is_running() -> bool:
		if __is_running.value != null:
			return true
		return false
	func get_is_running() -> bool:
		return __is_running.value
	func clear_is_running() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__is_running.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_is_running(value : bool) -> void:
		__is_running.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class AimInputMessage:
	func _init():
		var service
		
		__game_id = PBField.new("game_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __game_id
		data[__game_id.tag] = service
		
		__aim_x = PBField.new("aim_x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __aim_x
		data[__aim_x.tag] = service
		
		__aim_y = PBField.new("aim_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __aim_y
		data[__aim_y.tag] = service
		
	var data = {}
	
	var __game_id: PBField
	func has_game_id() -> bool:
		if __game_id.value != null:
			return true
		return false
	func get_game_id() -> int:
		return __game_id.value
	func clear_game_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__game_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_game_id(value : int) -> void:
		__game_id.value = value
	
	var __aim_x: PBField
	func has_aim_x() -> bool:
		if __aim_x.value != null:
			return true
		return false
	func get_aim_x() -> float:
		return __aim_x.value
	func clear_aim_x() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__aim_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_aim_x(value : float) -> void:
		__aim_x.value = value
	
	var __aim_y: PBField
	func has_aim_y() -> bool:
		if __aim_y.value != null:
			return true
		return false
	func get_aim_y() -> float:
		return __aim_y.value
	func clear_aim_y() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__aim_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_aim_y(value : float) -> void:
		__aim_y.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class PlayerAimUpdatedMessage:
	func _init():
		var service
		
		__game_id = PBField.new("game_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __game_id
		data[__game_id.tag] = service
		
		__player_id = PBField.new("player_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __player_id
		data[__player_id.tag] = service
		
		__aim_x = PBField.new("aim_x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __aim_x
		data[__aim_x.tag] = service
		
		__aim_y = PBField.new("aim_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __aim_y
		data[__aim_y.tag] = service
		
	var data = {}
	
	var __game_id: PBField
	func has_game_id() -> bool:
		if __game_id.value != null:
			return true
		return false
	func get_game_id() -> int:
		return __game_id.value
	func clear_game_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__game_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_game_id(value : int) -> void:
		__game_id.value = value
	
	var __player_id: PBField
	func has_player_id() -> bool:
		if __player_id.value != null:
			return true
		return false
	func get_player_id() -> int:
		return __player_id.value
	func clear_player_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__player_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_player_id(value : int) -> void:
		__player_id.value = value
	
	var __aim_x: PBField
	func has_aim_x() -> bool:
		if __aim_x.value != null:
			return true
		return false
	func get_aim_x() -> float:
		return __aim_x.value
	func clear_aim_x() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__aim_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_aim_x(value : float) -> void:
		__aim_x.value = value
	
	var __aim_y: PBField
	func has_aim_y() -> bool:
		if __aim_y.value != null:
			return true
		return false
	func get_aim_y() -> float:
		return __aim_y.value
	func clear_aim_y() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__aim_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_aim_y(value : float) -> void:
		__aim_y.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class ShootRequestMessage:
	func _init():
		var service
		
		__game_id = PBField.new("game_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __game_id
		data[__game_id.tag] = service
		
		__aim_x = PBField.new("aim_x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __aim_x
		data[__aim_x.tag] = service
		
		__aim_y = PBField.new("aim_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __aim_y
		data[__aim_y.tag] = service
		
	var data = {}
	
	var __game_id: PBField
	func has_game_id() -> bool:
		if __game_id.value != null:
			return true
		return false
	func get_game_id() -> int:
		return __game_id.value
	func clear_game_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__game_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_game_id(value : int) -> void:
		__game_id.value = value
	
	var __aim_x: PBField
	func has_aim_x() -> bool:
		if __aim_x.value != null:
			return true
		return false
	func get_aim_x() -> float:
		return __aim_x.value
	func clear_aim_x() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__aim_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_aim_x(value : float) -> void:
		__aim_x.value = value
	
	var __aim_y: PBField
	func has_aim_y() -> bool:
		if __aim_y.value != null:
			return true
		return false
	func get_aim_y() -> float:
		return __aim_y.value
	func clear_aim_y() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__aim_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_aim_y(value : float) -> void:
		__aim_y.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class BulletSpawnedMessage:
	func _init():
		var service
		
		__game_id = PBField.new("game_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __game_id
		data[__game_id.tag] = service
		
		__bullet_id = PBField.new("bullet_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __bullet_id
		data[__bullet_id.tag] = service
		
		__owner_player_id = PBField.new("owner_player_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __owner_player_id
		data[__owner_player_id.tag] = service
		
		__x = PBField.new("x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __x
		data[__x.tag] = service
		
		__y = PBField.new("y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __y
		data[__y.tag] = service
		
		__dir_x = PBField.new("dir_x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __dir_x
		data[__dir_x.tag] = service
		
		__dir_y = PBField.new("dir_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __dir_y
		data[__dir_y.tag] = service
		
		__speed_tiles_per_second = PBField.new("speed_tiles_per_second", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __speed_tiles_per_second
		data[__speed_tiles_per_second.tag] = service
		
		__lifetime_seconds = PBField.new("lifetime_seconds", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __lifetime_seconds
		data[__lifetime_seconds.tag] = service
		
	var data = {}
	
	var __game_id: PBField
	func has_game_id() -> bool:
		if __game_id.value != null:
			return true
		return false
	func get_game_id() -> int:
		return __game_id.value
	func clear_game_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__game_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_game_id(value : int) -> void:
		__game_id.value = value
	
	var __bullet_id: PBField
	func has_bullet_id() -> bool:
		if __bullet_id.value != null:
			return true
		return false
	func get_bullet_id() -> int:
		return __bullet_id.value
	func clear_bullet_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__bullet_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_bullet_id(value : int) -> void:
		__bullet_id.value = value
	
	var __owner_player_id: PBField
	func has_owner_player_id() -> bool:
		if __owner_player_id.value != null:
			return true
		return false
	func get_owner_player_id() -> int:
		return __owner_player_id.value
	func clear_owner_player_id() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__owner_player_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_owner_player_id(value : int) -> void:
		__owner_player_id.value = value
	
	var __x: PBField
	func has_x() -> bool:
		if __x.value != null:
			return true
		return false
	func get_x() -> float:
		return __x.value
	func clear_x() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_x(value : float) -> void:
		__x.value = value
	
	var __y: PBField
	func has_y() -> bool:
		if __y.value != null:
			return true
		return false
	func get_y() -> float:
		return __y.value
	func clear_y() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_y(value : float) -> void:
		__y.value = value
	
	var __dir_x: PBField
	func has_dir_x() -> bool:
		if __dir_x.value != null:
			return true
		return false
	func get_dir_x() -> float:
		return __dir_x.value
	func clear_dir_x() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__dir_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_dir_x(value : float) -> void:
		__dir_x.value = value
	
	var __dir_y: PBField
	func has_dir_y() -> bool:
		if __dir_y.value != null:
			return true
		return false
	func get_dir_y() -> float:
		return __dir_y.value
	func clear_dir_y() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__dir_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_dir_y(value : float) -> void:
		__dir_y.value = value
	
	var __speed_tiles_per_second: PBField
	func has_speed_tiles_per_second() -> bool:
		if __speed_tiles_per_second.value != null:
			return true
		return false
	func get_speed_tiles_per_second() -> float:
		return __speed_tiles_per_second.value
	func clear_speed_tiles_per_second() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__speed_tiles_per_second.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_speed_tiles_per_second(value : float) -> void:
		__speed_tiles_per_second.value = value
	
	var __lifetime_seconds: PBField
	func has_lifetime_seconds() -> bool:
		if __lifetime_seconds.value != null:
			return true
		return false
	func get_lifetime_seconds() -> float:
		return __lifetime_seconds.value
	func clear_lifetime_seconds() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__lifetime_seconds.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_lifetime_seconds(value : float) -> void:
		__lifetime_seconds.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class BulletHitMessage:
	func _init():
		var service
		
		__game_id = PBField.new("game_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __game_id
		data[__game_id.tag] = service
		
		__bullet_id = PBField.new("bullet_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __bullet_id
		data[__bullet_id.tag] = service
		
		__owner_player_id = PBField.new("owner_player_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __owner_player_id
		data[__owner_player_id.tag] = service
		
		__victim_player_id = PBField.new("victim_player_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __victim_player_id
		data[__victim_player_id.tag] = service
		
		__damage = PBField.new("damage", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __damage
		data[__damage.tag] = service
		
		__current_hp = PBField.new("current_hp", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __current_hp
		data[__current_hp.tag] = service
		
		__max_hp = PBField.new("max_hp", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __max_hp
		data[__max_hp.tag] = service
		
		__x = PBField.new("x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __x
		data[__x.tag] = service
		
		__y = PBField.new("y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __y
		data[__y.tag] = service
		
	var data = {}
	
	var __game_id: PBField
	func has_game_id() -> bool:
		if __game_id.value != null:
			return true
		return false
	func get_game_id() -> int:
		return __game_id.value
	func clear_game_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__game_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_game_id(value : int) -> void:
		__game_id.value = value
	
	var __bullet_id: PBField
	func has_bullet_id() -> bool:
		if __bullet_id.value != null:
			return true
		return false
	func get_bullet_id() -> int:
		return __bullet_id.value
	func clear_bullet_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__bullet_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_bullet_id(value : int) -> void:
		__bullet_id.value = value
	
	var __owner_player_id: PBField
	func has_owner_player_id() -> bool:
		if __owner_player_id.value != null:
			return true
		return false
	func get_owner_player_id() -> int:
		return __owner_player_id.value
	func clear_owner_player_id() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__owner_player_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_owner_player_id(value : int) -> void:
		__owner_player_id.value = value
	
	var __victim_player_id: PBField
	func has_victim_player_id() -> bool:
		if __victim_player_id.value != null:
			return true
		return false
	func get_victim_player_id() -> int:
		return __victim_player_id.value
	func clear_victim_player_id() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__victim_player_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_victim_player_id(value : int) -> void:
		__victim_player_id.value = value
	
	var __damage: PBField
	func has_damage() -> bool:
		if __damage.value != null:
			return true
		return false
	func get_damage() -> int:
		return __damage.value
	func clear_damage() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_damage(value : int) -> void:
		__damage.value = value
	
	var __current_hp: PBField
	func has_current_hp() -> bool:
		if __current_hp.value != null:
			return true
		return false
	func get_current_hp() -> int:
		return __current_hp.value
	func clear_current_hp() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__current_hp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_current_hp(value : int) -> void:
		__current_hp.value = value
	
	var __max_hp: PBField
	func has_max_hp() -> bool:
		if __max_hp.value != null:
			return true
		return false
	func get_max_hp() -> int:
		return __max_hp.value
	func clear_max_hp() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__max_hp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_max_hp(value : int) -> void:
		__max_hp.value = value
	
	var __x: PBField
	func has_x() -> bool:
		if __x.value != null:
			return true
		return false
	func get_x() -> float:
		return __x.value
	func clear_x() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_x(value : float) -> void:
		__x.value = value
	
	var __y: PBField
	func has_y() -> bool:
		if __y.value != null:
			return true
		return false
	func get_y() -> float:
		return __y.value
	func clear_y() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_y(value : float) -> void:
		__y.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class SkillRequestMessage:
	func _init():
		var service
		
		__game_id = PBField.new("game_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __game_id
		data[__game_id.tag] = service
		
		__skill_id = PBField.new("skill_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __skill_id
		data[__skill_id.tag] = service
		
		__target_x = PBField.new("target_x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __target_x
		data[__target_x.tag] = service
		
		__target_y = PBField.new("target_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __target_y
		data[__target_y.tag] = service
		
	var data = {}
	
	var __game_id: PBField
	func has_game_id() -> bool:
		if __game_id.value != null:
			return true
		return false
	func get_game_id() -> int:
		return __game_id.value
	func clear_game_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__game_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_game_id(value : int) -> void:
		__game_id.value = value
	
	var __skill_id: PBField
	func has_skill_id() -> bool:
		if __skill_id.value != null:
			return true
		return false
	func get_skill_id() -> int:
		return __skill_id.value
	func clear_skill_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__skill_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_skill_id(value : int) -> void:
		__skill_id.value = value
	
	var __target_x: PBField
	func has_target_x() -> bool:
		if __target_x.value != null:
			return true
		return false
	func get_target_x() -> float:
		return __target_x.value
	func clear_target_x() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__target_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_target_x(value : float) -> void:
		__target_x.value = value
	
	var __target_y: PBField
	func has_target_y() -> bool:
		if __target_y.value != null:
			return true
		return false
	func get_target_y() -> float:
		return __target_y.value
	func clear_target_y() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__target_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_target_y(value : float) -> void:
		__target_y.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class SkillActivatedMessage:
	func _init():
		var service
		
		__game_id = PBField.new("game_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __game_id
		data[__game_id.tag] = service
		
		__player_id = PBField.new("player_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __player_id
		data[__player_id.tag] = service
		
		__skill_id = PBField.new("skill_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __skill_id
		data[__skill_id.tag] = service
		
		__active_ms = PBField.new("active_ms", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __active_ms
		data[__active_ms.tag] = service
		
		__cooldown_ms = PBField.new("cooldown_ms", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __cooldown_ms
		data[__cooldown_ms.tag] = service
		
		__target_x = PBField.new("target_x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __target_x
		data[__target_x.tag] = service
		
		__target_y = PBField.new("target_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __target_y
		data[__target_y.tag] = service
		
	var data = {}
	
	var __game_id: PBField
	func has_game_id() -> bool:
		if __game_id.value != null:
			return true
		return false
	func get_game_id() -> int:
		return __game_id.value
	func clear_game_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__game_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_game_id(value : int) -> void:
		__game_id.value = value
	
	var __player_id: PBField
	func has_player_id() -> bool:
		if __player_id.value != null:
			return true
		return false
	func get_player_id() -> int:
		return __player_id.value
	func clear_player_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__player_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_player_id(value : int) -> void:
		__player_id.value = value
	
	var __skill_id: PBField
	func has_skill_id() -> bool:
		if __skill_id.value != null:
			return true
		return false
	func get_skill_id() -> int:
		return __skill_id.value
	func clear_skill_id() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__skill_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_skill_id(value : int) -> void:
		__skill_id.value = value
	
	var __active_ms: PBField
	func has_active_ms() -> bool:
		if __active_ms.value != null:
			return true
		return false
	func get_active_ms() -> int:
		return __active_ms.value
	func clear_active_ms() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__active_ms.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_active_ms(value : int) -> void:
		__active_ms.value = value
	
	var __cooldown_ms: PBField
	func has_cooldown_ms() -> bool:
		if __cooldown_ms.value != null:
			return true
		return false
	func get_cooldown_ms() -> int:
		return __cooldown_ms.value
	func clear_cooldown_ms() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__cooldown_ms.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_cooldown_ms(value : int) -> void:
		__cooldown_ms.value = value
	
	var __target_x: PBField
	func has_target_x() -> bool:
		if __target_x.value != null:
			return true
		return false
	func get_target_x() -> float:
		return __target_x.value
	func clear_target_x() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__target_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_target_x(value : float) -> void:
		__target_x.value = value
	
	var __target_y: PBField
	func has_target_y() -> bool:
		if __target_y.value != null:
			return true
		return false
	func get_target_y() -> float:
		return __target_y.value
	func clear_target_y() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__target_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_target_y(value : float) -> void:
		__target_y.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class PlayerHealedMessage:
	func _init():
		var service
		
		__game_id = PBField.new("game_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __game_id
		data[__game_id.tag] = service
		
		__healer_player_id = PBField.new("healer_player_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __healer_player_id
		data[__healer_player_id.tag] = service
		
		__target_player_id = PBField.new("target_player_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __target_player_id
		data[__target_player_id.tag] = service
		
		__amount = PBField.new("amount", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __amount
		data[__amount.tag] = service
		
		__current_hp = PBField.new("current_hp", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __current_hp
		data[__current_hp.tag] = service
		
		__max_hp = PBField.new("max_hp", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __max_hp
		data[__max_hp.tag] = service
		
		__x = PBField.new("x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __x
		data[__x.tag] = service
		
		__y = PBField.new("y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __y
		data[__y.tag] = service
		
	var data = {}
	
	var __game_id: PBField
	func has_game_id() -> bool:
		if __game_id.value != null:
			return true
		return false
	func get_game_id() -> int:
		return __game_id.value
	func clear_game_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__game_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_game_id(value : int) -> void:
		__game_id.value = value
	
	var __healer_player_id: PBField
	func has_healer_player_id() -> bool:
		if __healer_player_id.value != null:
			return true
		return false
	func get_healer_player_id() -> int:
		return __healer_player_id.value
	func clear_healer_player_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__healer_player_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_healer_player_id(value : int) -> void:
		__healer_player_id.value = value
	
	var __target_player_id: PBField
	func has_target_player_id() -> bool:
		if __target_player_id.value != null:
			return true
		return false
	func get_target_player_id() -> int:
		return __target_player_id.value
	func clear_target_player_id() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__target_player_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_target_player_id(value : int) -> void:
		__target_player_id.value = value
	
	var __amount: PBField
	func has_amount() -> bool:
		if __amount.value != null:
			return true
		return false
	func get_amount() -> int:
		return __amount.value
	func clear_amount() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__amount.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_amount(value : int) -> void:
		__amount.value = value
	
	var __current_hp: PBField
	func has_current_hp() -> bool:
		if __current_hp.value != null:
			return true
		return false
	func get_current_hp() -> int:
		return __current_hp.value
	func clear_current_hp() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__current_hp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_current_hp(value : int) -> void:
		__current_hp.value = value
	
	var __max_hp: PBField
	func has_max_hp() -> bool:
		if __max_hp.value != null:
			return true
		return false
	func get_max_hp() -> int:
		return __max_hp.value
	func clear_max_hp() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__max_hp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_max_hp(value : int) -> void:
		__max_hp.value = value
	
	var __x: PBField
	func has_x() -> bool:
		if __x.value != null:
			return true
		return false
	func get_x() -> float:
		return __x.value
	func clear_x() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_x(value : float) -> void:
		__x.value = value
	
	var __y: PBField
	func has_y() -> bool:
		if __y.value != null:
			return true
		return false
	func get_y() -> float:
		return __y.value
	func clear_y() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_y(value : float) -> void:
		__y.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class MolotovSpawnedMessage:
	func _init():
		var service
		
		__game_id = PBField.new("game_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __game_id
		data[__game_id.tag] = service
		
		__molotov_id = PBField.new("molotov_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __molotov_id
		data[__molotov_id.tag] = service
		
		__owner_player_id = PBField.new("owner_player_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __owner_player_id
		data[__owner_player_id.tag] = service
		
		__x = PBField.new("x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __x
		data[__x.tag] = service
		
		__y = PBField.new("y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __y
		data[__y.tag] = service
		
		__radius_tiles = PBField.new("radius_tiles", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __radius_tiles
		data[__radius_tiles.tag] = service
		
		__duration_seconds = PBField.new("duration_seconds", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __duration_seconds
		data[__duration_seconds.tag] = service
		
	var data = {}
	
	var __game_id: PBField
	func has_game_id() -> bool:
		if __game_id.value != null:
			return true
		return false
	func get_game_id() -> int:
		return __game_id.value
	func clear_game_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__game_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_game_id(value : int) -> void:
		__game_id.value = value
	
	var __molotov_id: PBField
	func has_molotov_id() -> bool:
		if __molotov_id.value != null:
			return true
		return false
	func get_molotov_id() -> int:
		return __molotov_id.value
	func clear_molotov_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__molotov_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_molotov_id(value : int) -> void:
		__molotov_id.value = value
	
	var __owner_player_id: PBField
	func has_owner_player_id() -> bool:
		if __owner_player_id.value != null:
			return true
		return false
	func get_owner_player_id() -> int:
		return __owner_player_id.value
	func clear_owner_player_id() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__owner_player_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_owner_player_id(value : int) -> void:
		__owner_player_id.value = value
	
	var __x: PBField
	func has_x() -> bool:
		if __x.value != null:
			return true
		return false
	func get_x() -> float:
		return __x.value
	func clear_x() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_x(value : float) -> void:
		__x.value = value
	
	var __y: PBField
	func has_y() -> bool:
		if __y.value != null:
			return true
		return false
	func get_y() -> float:
		return __y.value
	func clear_y() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_y(value : float) -> void:
		__y.value = value
	
	var __radius_tiles: PBField
	func has_radius_tiles() -> bool:
		if __radius_tiles.value != null:
			return true
		return false
	func get_radius_tiles() -> float:
		return __radius_tiles.value
	func clear_radius_tiles() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__radius_tiles.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_radius_tiles(value : float) -> void:
		__radius_tiles.value = value
	
	var __duration_seconds: PBField
	func has_duration_seconds() -> bool:
		if __duration_seconds.value != null:
			return true
		return false
	func get_duration_seconds() -> float:
		return __duration_seconds.value
	func clear_duration_seconds() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__duration_seconds.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_duration_seconds(value : float) -> void:
		__duration_seconds.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class SkillDamageMessage:
	func _init():
		var service
		
		__game_id = PBField.new("game_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __game_id
		data[__game_id.tag] = service
		
		__skill_id = PBField.new("skill_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __skill_id
		data[__skill_id.tag] = service
		
		__source_player_id = PBField.new("source_player_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __source_player_id
		data[__source_player_id.tag] = service
		
		__victim_player_id = PBField.new("victim_player_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __victim_player_id
		data[__victim_player_id.tag] = service
		
		__damage = PBField.new("damage", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __damage
		data[__damage.tag] = service
		
		__current_hp = PBField.new("current_hp", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __current_hp
		data[__current_hp.tag] = service
		
		__max_hp = PBField.new("max_hp", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __max_hp
		data[__max_hp.tag] = service
		
		__x = PBField.new("x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __x
		data[__x.tag] = service
		
		__y = PBField.new("y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __y
		data[__y.tag] = service
		
	var data = {}
	
	var __game_id: PBField
	func has_game_id() -> bool:
		if __game_id.value != null:
			return true
		return false
	func get_game_id() -> int:
		return __game_id.value
	func clear_game_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__game_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_game_id(value : int) -> void:
		__game_id.value = value
	
	var __skill_id: PBField
	func has_skill_id() -> bool:
		if __skill_id.value != null:
			return true
		return false
	func get_skill_id() -> int:
		return __skill_id.value
	func clear_skill_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__skill_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_skill_id(value : int) -> void:
		__skill_id.value = value
	
	var __source_player_id: PBField
	func has_source_player_id() -> bool:
		if __source_player_id.value != null:
			return true
		return false
	func get_source_player_id() -> int:
		return __source_player_id.value
	func clear_source_player_id() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__source_player_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_source_player_id(value : int) -> void:
		__source_player_id.value = value
	
	var __victim_player_id: PBField
	func has_victim_player_id() -> bool:
		if __victim_player_id.value != null:
			return true
		return false
	func get_victim_player_id() -> int:
		return __victim_player_id.value
	func clear_victim_player_id() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__victim_player_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_victim_player_id(value : int) -> void:
		__victim_player_id.value = value
	
	var __damage: PBField
	func has_damage() -> bool:
		if __damage.value != null:
			return true
		return false
	func get_damage() -> int:
		return __damage.value
	func clear_damage() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_damage(value : int) -> void:
		__damage.value = value
	
	var __current_hp: PBField
	func has_current_hp() -> bool:
		if __current_hp.value != null:
			return true
		return false
	func get_current_hp() -> int:
		return __current_hp.value
	func clear_current_hp() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__current_hp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_current_hp(value : int) -> void:
		__current_hp.value = value
	
	var __max_hp: PBField
	func has_max_hp() -> bool:
		if __max_hp.value != null:
			return true
		return false
	func get_max_hp() -> int:
		return __max_hp.value
	func clear_max_hp() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__max_hp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_max_hp(value : int) -> void:
		__max_hp.value = value
	
	var __x: PBField
	func has_x() -> bool:
		if __x.value != null:
			return true
		return false
	func get_x() -> float:
		return __x.value
	func clear_x() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_x(value : float) -> void:
		__x.value = value
	
	var __y: PBField
	func has_y() -> bool:
		if __y.value != null:
			return true
		return false
	func get_y() -> float:
		return __y.value
	func clear_y() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_y(value : float) -> void:
		__y.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class PlayerDiedMessage:
	func _init():
		var service
		
		__game_id = PBField.new("game_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __game_id
		data[__game_id.tag] = service
		
		__player_id = PBField.new("player_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __player_id
		data[__player_id.tag] = service
		
		__respawn_seconds = PBField.new("respawn_seconds", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __respawn_seconds
		data[__respawn_seconds.tag] = service
		
	var data = {}
	
	var __game_id: PBField
	func has_game_id() -> bool:
		if __game_id.value != null:
			return true
		return false
	func get_game_id() -> int:
		return __game_id.value
	func clear_game_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__game_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_game_id(value : int) -> void:
		__game_id.value = value
	
	var __player_id: PBField
	func has_player_id() -> bool:
		if __player_id.value != null:
			return true
		return false
	func get_player_id() -> int:
		return __player_id.value
	func clear_player_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__player_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_player_id(value : int) -> void:
		__player_id.value = value
	
	var __respawn_seconds: PBField
	func has_respawn_seconds() -> bool:
		if __respawn_seconds.value != null:
			return true
		return false
	func get_respawn_seconds() -> int:
		return __respawn_seconds.value
	func clear_respawn_seconds() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__respawn_seconds.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_respawn_seconds(value : int) -> void:
		__respawn_seconds.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class PlayerRespawnedMessage:
	func _init():
		var service
		
		__game_id = PBField.new("game_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __game_id
		data[__game_id.tag] = service
		
		__player_id = PBField.new("player_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __player_id
		data[__player_id.tag] = service
		
		__x = PBField.new("x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __x
		data[__x.tag] = service
		
		__y = PBField.new("y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __y
		data[__y.tag] = service
		
		__current_hp = PBField.new("current_hp", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __current_hp
		data[__current_hp.tag] = service
		
		__max_hp = PBField.new("max_hp", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __max_hp
		data[__max_hp.tag] = service
		
	var data = {}
	
	var __game_id: PBField
	func has_game_id() -> bool:
		if __game_id.value != null:
			return true
		return false
	func get_game_id() -> int:
		return __game_id.value
	func clear_game_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__game_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_game_id(value : int) -> void:
		__game_id.value = value
	
	var __player_id: PBField
	func has_player_id() -> bool:
		if __player_id.value != null:
			return true
		return false
	func get_player_id() -> int:
		return __player_id.value
	func clear_player_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__player_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_player_id(value : int) -> void:
		__player_id.value = value
	
	var __x: PBField
	func has_x() -> bool:
		if __x.value != null:
			return true
		return false
	func get_x() -> float:
		return __x.value
	func clear_x() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_x(value : float) -> void:
		__x.value = value
	
	var __y: PBField
	func has_y() -> bool:
		if __y.value != null:
			return true
		return false
	func get_y() -> float:
		return __y.value
	func clear_y() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_y(value : float) -> void:
		__y.value = value
	
	var __current_hp: PBField
	func has_current_hp() -> bool:
		if __current_hp.value != null:
			return true
		return false
	func get_current_hp() -> int:
		return __current_hp.value
	func clear_current_hp() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__current_hp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_current_hp(value : int) -> void:
		__current_hp.value = value
	
	var __max_hp: PBField
	func has_max_hp() -> bool:
		if __max_hp.value != null:
			return true
		return false
	func get_max_hp() -> int:
		return __max_hp.value
	func clear_max_hp() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__max_hp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_max_hp(value : int) -> void:
		__max_hp.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class MatchPlayerResultMessage:
	func _init():
		var service
		
		__player_id = PBField.new("player_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __player_id
		data[__player_id.tag] = service
		
		__nickname = PBField.new("nickname", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __nickname
		data[__nickname.tag] = service
		
		__team = PBField.new("team", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __team
		data[__team.tag] = service
		
		__kills = PBField.new("kills", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __kills
		data[__kills.tag] = service
		
		__deaths = PBField.new("deaths", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __deaths
		data[__deaths.tag] = service
		
		__captures = PBField.new("captures", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __captures
		data[__captures.tag] = service
		
		__won = PBField.new("won", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __won
		data[__won.tag] = service
		
		__lost = PBField.new("lost", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __lost
		data[__lost.tag] = service
		
	var data = {}
	
	var __player_id: PBField
	func has_player_id() -> bool:
		if __player_id.value != null:
			return true
		return false
	func get_player_id() -> int:
		return __player_id.value
	func clear_player_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__player_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_player_id(value : int) -> void:
		__player_id.value = value
	
	var __nickname: PBField
	func has_nickname() -> bool:
		if __nickname.value != null:
			return true
		return false
	func get_nickname() -> String:
		return __nickname.value
	func clear_nickname() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__nickname.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_nickname(value : String) -> void:
		__nickname.value = value
	
	var __team: PBField
	func has_team() -> bool:
		if __team.value != null:
			return true
		return false
	func get_team() -> int:
		return __team.value
	func clear_team() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__team.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_team(value : int) -> void:
		__team.value = value
	
	var __kills: PBField
	func has_kills() -> bool:
		if __kills.value != null:
			return true
		return false
	func get_kills() -> int:
		return __kills.value
	func clear_kills() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__kills.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_kills(value : int) -> void:
		__kills.value = value
	
	var __deaths: PBField
	func has_deaths() -> bool:
		if __deaths.value != null:
			return true
		return false
	func get_deaths() -> int:
		return __deaths.value
	func clear_deaths() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__deaths.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_deaths(value : int) -> void:
		__deaths.value = value
	
	var __captures: PBField
	func has_captures() -> bool:
		if __captures.value != null:
			return true
		return false
	func get_captures() -> int:
		return __captures.value
	func clear_captures() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__captures.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_captures(value : int) -> void:
		__captures.value = value
	
	var __won: PBField
	func has_won() -> bool:
		if __won.value != null:
			return true
		return false
	func get_won() -> bool:
		return __won.value
	func clear_won() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__won.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_won(value : bool) -> void:
		__won.value = value
	
	var __lost: PBField
	func has_lost() -> bool:
		if __lost.value != null:
			return true
		return false
	func get_lost() -> bool:
		return __lost.value
	func clear_lost() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__lost.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_lost(value : bool) -> void:
		__lost.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class MatchEndedMessage:
	func _init():
		var service
		
		__game_id = PBField.new("game_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __game_id
		data[__game_id.tag] = service
		
		__red_score = PBField.new("red_score", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __red_score
		data[__red_score.tag] = service
		
		__blue_score = PBField.new("blue_score", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __blue_score
		data[__blue_score.tag] = service
		
		__winning_team = PBField.new("winning_team", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __winning_team
		data[__winning_team.tag] = service
		
		__reason = PBField.new("reason", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __reason
		data[__reason.tag] = service
		
		var __results_default: Array[MatchPlayerResultMessage] = []
		__results = PBField.new("results", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 6, true, __results_default)
		service = PBServiceField.new()
		service.field = __results
		service.func_ref = Callable(self, "add_results")
		data[__results.tag] = service
		
	var data = {}
	
	var __game_id: PBField
	func has_game_id() -> bool:
		if __game_id.value != null:
			return true
		return false
	func get_game_id() -> int:
		return __game_id.value
	func clear_game_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__game_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_game_id(value : int) -> void:
		__game_id.value = value
	
	var __red_score: PBField
	func has_red_score() -> bool:
		if __red_score.value != null:
			return true
		return false
	func get_red_score() -> int:
		return __red_score.value
	func clear_red_score() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__red_score.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_red_score(value : int) -> void:
		__red_score.value = value
	
	var __blue_score: PBField
	func has_blue_score() -> bool:
		if __blue_score.value != null:
			return true
		return false
	func get_blue_score() -> int:
		return __blue_score.value
	func clear_blue_score() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__blue_score.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_blue_score(value : int) -> void:
		__blue_score.value = value
	
	var __winning_team: PBField
	func has_winning_team() -> bool:
		if __winning_team.value != null:
			return true
		return false
	func get_winning_team() -> int:
		return __winning_team.value
	func clear_winning_team() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__winning_team.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_winning_team(value : int) -> void:
		__winning_team.value = value
	
	var __reason: PBField
	func has_reason() -> bool:
		if __reason.value != null:
			return true
		return false
	func get_reason() -> String:
		return __reason.value
	func clear_reason() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__reason.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_reason(value : String) -> void:
		__reason.value = value
	
	var __results: PBField
	func get_results() -> Array[MatchPlayerResultMessage]:
		return __results.value
	func clear_results() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__results.value.clear()
	func add_results() -> MatchPlayerResultMessage:
		var element = MatchPlayerResultMessage.new()
		__results.value.append(element)
		return element
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class RequestReturnToLobbyMessage:
	func _init():
		var service
		
	var data = {}
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
	
class Packet:
	func _init():
		var service
		
		__sender_id = PBField.new("sender_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __sender_id
		data[__sender_id.tag] = service
		
		__chat = PBField.new("chat", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __chat
		service.func_ref = Callable(self, "new_chat")
		data[__chat.tag] = service
		
		__id = PBField.new("id", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __id
		service.func_ref = Callable(self, "new_id")
		data[__id.tag] = service
		
		__login_request = PBField.new("login_request", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __login_request
		service.func_ref = Callable(self, "new_login_request")
		data[__login_request.tag] = service
		
		__register_request = PBField.new("register_request", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __register_request
		service.func_ref = Callable(self, "new_register_request")
		data[__register_request.tag] = service
		
		__ok_response = PBField.new("ok_response", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __ok_response
		service.func_ref = Callable(self, "new_ok_response")
		data[__ok_response.tag] = service
		
		__error_response = PBField.new("error_response", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __error_response
		service.func_ref = Callable(self, "new_error_response")
		data[__error_response.tag] = service
		
		__request_general_info = PBField.new("request_general_info", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __request_general_info
		service.func_ref = Callable(self, "new_request_general_info")
		data[__request_general_info.tag] = service
		
		__response_user_stats = PBField.new("response_user_stats", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __response_user_stats
		service.func_ref = Callable(self, "new_response_user_stats")
		data[__response_user_stats.tag] = service
		
		__response_user_name = PBField.new("response_user_name", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 10, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __response_user_name
		service.func_ref = Callable(self, "new_response_user_name")
		data[__response_user_name.tag] = service
		
		__response_user_skin = PBField.new("response_user_skin", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 11, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __response_user_skin
		service.func_ref = Callable(self, "new_response_user_skin")
		data[__response_user_skin.tag] = service
		
		__request_update_user_skin = PBField.new("request_update_user_skin", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 12, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __request_update_user_skin
		service.func_ref = Callable(self, "new_request_update_user_skin")
		data[__request_update_user_skin.tag] = service
		
		__request_enter_queue = PBField.new("request_enter_queue", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 13, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __request_enter_queue
		service.func_ref = Callable(self, "new_request_enter_queue")
		data[__request_enter_queue.tag] = service
		
		__request_leave_queue = PBField.new("request_leave_queue", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 14, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __request_leave_queue
		service.func_ref = Callable(self, "new_request_leave_queue")
		data[__request_leave_queue.tag] = service
		
		__queue_joined = PBField.new("queue_joined", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 15, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __queue_joined
		service.func_ref = Callable(self, "new_queue_joined")
		data[__queue_joined.tag] = service
		
		__queue_left = PBField.new("queue_left", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 16, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __queue_left
		service.func_ref = Callable(self, "new_queue_left")
		data[__queue_left.tag] = service
		
		__match_found = PBField.new("match_found", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 17, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __match_found
		service.func_ref = Callable(self, "new_match_found")
		data[__match_found.tag] = service
		
		__spawn_player = PBField.new("spawn_player", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 18, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __spawn_player
		service.func_ref = Callable(self, "new_spawn_player")
		data[__spawn_player.tag] = service
		
		__despawn_player = PBField.new("despawn_player", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 19, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __despawn_player
		service.func_ref = Callable(self, "new_despawn_player")
		data[__despawn_player.tag] = service
		
		__movement_input = PBField.new("movement_input", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 20, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __movement_input
		service.func_ref = Callable(self, "new_movement_input")
		data[__movement_input.tag] = service
		
		__player_moved = PBField.new("player_moved", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 21, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __player_moved
		service.func_ref = Callable(self, "new_player_moved")
		data[__player_moved.tag] = service
		
		__player_health_updated = PBField.new("player_health_updated", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 22, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __player_health_updated
		service.func_ref = Callable(self, "new_player_health_updated")
		data[__player_health_updated.tag] = service
		
		__spawn_flag = PBField.new("spawn_flag", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 23, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __spawn_flag
		service.func_ref = Callable(self, "new_spawn_flag")
		data[__spawn_flag.tag] = service
		
		__flag_state_updated = PBField.new("flag_state_updated", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 24, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __flag_state_updated
		service.func_ref = Callable(self, "new_flag_state_updated")
		data[__flag_state_updated.tag] = service
		
		__score_updated = PBField.new("score_updated", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 25, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __score_updated
		service.func_ref = Callable(self, "new_score_updated")
		data[__score_updated.tag] = service
		
		__game_time_updated = PBField.new("game_time_updated", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 26, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __game_time_updated
		service.func_ref = Callable(self, "new_game_time_updated")
		data[__game_time_updated.tag] = service
		
		__aim_input = PBField.new("aim_input", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 27, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __aim_input
		service.func_ref = Callable(self, "new_aim_input")
		data[__aim_input.tag] = service
		
		__player_aim_updated = PBField.new("player_aim_updated", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 28, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __player_aim_updated
		service.func_ref = Callable(self, "new_player_aim_updated")
		data[__player_aim_updated.tag] = service
		
		__shoot_request = PBField.new("shoot_request", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 29, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __shoot_request
		service.func_ref = Callable(self, "new_shoot_request")
		data[__shoot_request.tag] = service
		
		__bullet_spawned = PBField.new("bullet_spawned", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 30, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __bullet_spawned
		service.func_ref = Callable(self, "new_bullet_spawned")
		data[__bullet_spawned.tag] = service
		
		__bullet_hit = PBField.new("bullet_hit", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 31, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __bullet_hit
		service.func_ref = Callable(self, "new_bullet_hit")
		data[__bullet_hit.tag] = service
		
		__skill_request = PBField.new("skill_request", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 32, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __skill_request
		service.func_ref = Callable(self, "new_skill_request")
		data[__skill_request.tag] = service
		
		__skill_activated = PBField.new("skill_activated", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 33, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __skill_activated
		service.func_ref = Callable(self, "new_skill_activated")
		data[__skill_activated.tag] = service
		
		__player_healed = PBField.new("player_healed", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 34, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __player_healed
		service.func_ref = Callable(self, "new_player_healed")
		data[__player_healed.tag] = service
		
		__molotov_spawned = PBField.new("molotov_spawned", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 35, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __molotov_spawned
		service.func_ref = Callable(self, "new_molotov_spawned")
		data[__molotov_spawned.tag] = service
		
		__skill_damage = PBField.new("skill_damage", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 36, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __skill_damage
		service.func_ref = Callable(self, "new_skill_damage")
		data[__skill_damage.tag] = service
		
		__player_died = PBField.new("player_died", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 37, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __player_died
		service.func_ref = Callable(self, "new_player_died")
		data[__player_died.tag] = service
		
		__player_respawned = PBField.new("player_respawned", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 38, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __player_respawned
		service.func_ref = Callable(self, "new_player_respawned")
		data[__player_respawned.tag] = service
		
		__match_ended = PBField.new("match_ended", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 39, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __match_ended
		service.func_ref = Callable(self, "new_match_ended")
		data[__match_ended.tag] = service
		
		__request_return_to_lobby = PBField.new("request_return_to_lobby", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 40, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __request_return_to_lobby
		service.func_ref = Callable(self, "new_request_return_to_lobby")
		data[__request_return_to_lobby.tag] = service
		
	var data = {}
	
	var __sender_id: PBField
	func has_sender_id() -> bool:
		if __sender_id.value != null:
			return true
		return false
	func get_sender_id() -> int:
		return __sender_id.value
	func clear_sender_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__sender_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_sender_id(value : int) -> void:
		__sender_id.value = value
	
	var __chat: PBField
	func has_chat() -> bool:
		if __chat.value != null:
			return true
		return false
	func get_chat() -> ChatMessage:
		return __chat.value
	func clear_chat() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_chat() -> ChatMessage:
		data[2].state = PB_SERVICE_STATE.FILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__chat.value = ChatMessage.new()
		return __chat.value
	
	var __id: PBField
	func has_id() -> bool:
		if __id.value != null:
			return true
		return false
	func get_id() -> IdMessage:
		return __id.value
	func clear_id() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_id() -> IdMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		data[3].state = PB_SERVICE_STATE.FILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__id.value = IdMessage.new()
		return __id.value
	
	var __login_request: PBField
	func has_login_request() -> bool:
		if __login_request.value != null:
			return true
		return false
	func get_login_request() -> LoginRequestMessage:
		return __login_request.value
	func clear_login_request() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_login_request() -> LoginRequestMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		data[4].state = PB_SERVICE_STATE.FILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = LoginRequestMessage.new()
		return __login_request.value
	
	var __register_request: PBField
	func has_register_request() -> bool:
		if __register_request.value != null:
			return true
		return false
	func get_register_request() -> RegisterRequestMessage:
		return __register_request.value
	func clear_register_request() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_register_request() -> RegisterRequestMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		data[5].state = PB_SERVICE_STATE.FILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = RegisterRequestMessage.new()
		return __register_request.value
	
	var __ok_response: PBField
	func has_ok_response() -> bool:
		if __ok_response.value != null:
			return true
		return false
	func get_ok_response() -> OkResponseMessage:
		return __ok_response.value
	func clear_ok_response() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_ok_response() -> OkResponseMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		data[6].state = PB_SERVICE_STATE.FILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = OkResponseMessage.new()
		return __ok_response.value
	
	var __error_response: PBField
	func has_error_response() -> bool:
		if __error_response.value != null:
			return true
		return false
	func get_error_response() -> ErrorResponseMessage:
		return __error_response.value
	func clear_error_response() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_error_response() -> ErrorResponseMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		data[7].state = PB_SERVICE_STATE.FILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = ErrorResponseMessage.new()
		return __error_response.value
	
	var __request_general_info: PBField
	func has_request_general_info() -> bool:
		if __request_general_info.value != null:
			return true
		return false
	func get_request_general_info() -> RequestGeneralInfoMessage:
		return __request_general_info.value
	func clear_request_general_info() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_request_general_info() -> RequestGeneralInfoMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		data[8].state = PB_SERVICE_STATE.FILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = RequestGeneralInfoMessage.new()
		return __request_general_info.value
	
	var __response_user_stats: PBField
	func has_response_user_stats() -> bool:
		if __response_user_stats.value != null:
			return true
		return false
	func get_response_user_stats() -> ResponseUserStatsMessage:
		return __response_user_stats.value
	func clear_response_user_stats() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_response_user_stats() -> ResponseUserStatsMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		data[9].state = PB_SERVICE_STATE.FILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = ResponseUserStatsMessage.new()
		return __response_user_stats.value
	
	var __response_user_name: PBField
	func has_response_user_name() -> bool:
		if __response_user_name.value != null:
			return true
		return false
	func get_response_user_name() -> ResponseUserNameMessage:
		return __response_user_name.value
	func clear_response_user_name() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_response_user_name() -> ResponseUserNameMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		data[10].state = PB_SERVICE_STATE.FILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = ResponseUserNameMessage.new()
		return __response_user_name.value
	
	var __response_user_skin: PBField
	func has_response_user_skin() -> bool:
		if __response_user_skin.value != null:
			return true
		return false
	func get_response_user_skin() -> ResponseUserSkinMessage:
		return __response_user_skin.value
	func clear_response_user_skin() -> void:
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_response_user_skin() -> ResponseUserSkinMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		data[11].state = PB_SERVICE_STATE.FILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = ResponseUserSkinMessage.new()
		return __response_user_skin.value
	
	var __request_update_user_skin: PBField
	func has_request_update_user_skin() -> bool:
		if __request_update_user_skin.value != null:
			return true
		return false
	func get_request_update_user_skin() -> RequestUpdateUserSkinMessage:
		return __request_update_user_skin.value
	func clear_request_update_user_skin() -> void:
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_request_update_user_skin() -> RequestUpdateUserSkinMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		data[12].state = PB_SERVICE_STATE.FILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = RequestUpdateUserSkinMessage.new()
		return __request_update_user_skin.value
	
	var __request_enter_queue: PBField
	func has_request_enter_queue() -> bool:
		if __request_enter_queue.value != null:
			return true
		return false
	func get_request_enter_queue() -> RequestEnterQueueMessage:
		return __request_enter_queue.value
	func clear_request_enter_queue() -> void:
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_request_enter_queue() -> RequestEnterQueueMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		data[13].state = PB_SERVICE_STATE.FILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = RequestEnterQueueMessage.new()
		return __request_enter_queue.value
	
	var __request_leave_queue: PBField
	func has_request_leave_queue() -> bool:
		if __request_leave_queue.value != null:
			return true
		return false
	func get_request_leave_queue() -> RequestLeaveQueueMessage:
		return __request_leave_queue.value
	func clear_request_leave_queue() -> void:
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_request_leave_queue() -> RequestLeaveQueueMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		data[14].state = PB_SERVICE_STATE.FILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = RequestLeaveQueueMessage.new()
		return __request_leave_queue.value
	
	var __queue_joined: PBField
	func has_queue_joined() -> bool:
		if __queue_joined.value != null:
			return true
		return false
	func get_queue_joined() -> QueueJoinedMessage:
		return __queue_joined.value
	func clear_queue_joined() -> void:
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_queue_joined() -> QueueJoinedMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		data[15].state = PB_SERVICE_STATE.FILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = QueueJoinedMessage.new()
		return __queue_joined.value
	
	var __queue_left: PBField
	func has_queue_left() -> bool:
		if __queue_left.value != null:
			return true
		return false
	func get_queue_left() -> QueueLeftMessage:
		return __queue_left.value
	func clear_queue_left() -> void:
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_queue_left() -> QueueLeftMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		data[16].state = PB_SERVICE_STATE.FILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = QueueLeftMessage.new()
		return __queue_left.value
	
	var __match_found: PBField
	func has_match_found() -> bool:
		if __match_found.value != null:
			return true
		return false
	func get_match_found() -> MatchFoundMessage:
		return __match_found.value
	func clear_match_found() -> void:
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_match_found() -> MatchFoundMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		data[17].state = PB_SERVICE_STATE.FILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = MatchFoundMessage.new()
		return __match_found.value
	
	var __spawn_player: PBField
	func has_spawn_player() -> bool:
		if __spawn_player.value != null:
			return true
		return false
	func get_spawn_player() -> SpawnPlayerMessage:
		return __spawn_player.value
	func clear_spawn_player() -> void:
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_spawn_player() -> SpawnPlayerMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		data[18].state = PB_SERVICE_STATE.FILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = SpawnPlayerMessage.new()
		return __spawn_player.value
	
	var __despawn_player: PBField
	func has_despawn_player() -> bool:
		if __despawn_player.value != null:
			return true
		return false
	func get_despawn_player() -> DespawnPlayerMessage:
		return __despawn_player.value
	func clear_despawn_player() -> void:
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_despawn_player() -> DespawnPlayerMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		data[19].state = PB_SERVICE_STATE.FILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DespawnPlayerMessage.new()
		return __despawn_player.value
	
	var __movement_input: PBField
	func has_movement_input() -> bool:
		if __movement_input.value != null:
			return true
		return false
	func get_movement_input() -> MovementInputMessage:
		return __movement_input.value
	func clear_movement_input() -> void:
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_movement_input() -> MovementInputMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		data[20].state = PB_SERVICE_STATE.FILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = MovementInputMessage.new()
		return __movement_input.value
	
	var __player_moved: PBField
	func has_player_moved() -> bool:
		if __player_moved.value != null:
			return true
		return false
	func get_player_moved() -> PlayerMovedMessage:
		return __player_moved.value
	func clear_player_moved() -> void:
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_player_moved() -> PlayerMovedMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		data[21].state = PB_SERVICE_STATE.FILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = PlayerMovedMessage.new()
		return __player_moved.value
	
	var __player_health_updated: PBField
	func has_player_health_updated() -> bool:
		if __player_health_updated.value != null:
			return true
		return false
	func get_player_health_updated() -> PlayerHealthUpdatedMessage:
		return __player_health_updated.value
	func clear_player_health_updated() -> void:
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_player_health_updated() -> PlayerHealthUpdatedMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		data[22].state = PB_SERVICE_STATE.FILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = PlayerHealthUpdatedMessage.new()
		return __player_health_updated.value
	
	var __spawn_flag: PBField
	func has_spawn_flag() -> bool:
		if __spawn_flag.value != null:
			return true
		return false
	func get_spawn_flag() -> SpawnFlagMessage:
		return __spawn_flag.value
	func clear_spawn_flag() -> void:
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_spawn_flag() -> SpawnFlagMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		data[23].state = PB_SERVICE_STATE.FILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = SpawnFlagMessage.new()
		return __spawn_flag.value
	
	var __flag_state_updated: PBField
	func has_flag_state_updated() -> bool:
		if __flag_state_updated.value != null:
			return true
		return false
	func get_flag_state_updated() -> FlagStateUpdatedMessage:
		return __flag_state_updated.value
	func clear_flag_state_updated() -> void:
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_flag_state_updated() -> FlagStateUpdatedMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		data[24].state = PB_SERVICE_STATE.FILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = FlagStateUpdatedMessage.new()
		return __flag_state_updated.value
	
	var __score_updated: PBField
	func has_score_updated() -> bool:
		if __score_updated.value != null:
			return true
		return false
	func get_score_updated() -> ScoreUpdatedMessage:
		return __score_updated.value
	func clear_score_updated() -> void:
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_score_updated() -> ScoreUpdatedMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		data[25].state = PB_SERVICE_STATE.FILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = ScoreUpdatedMessage.new()
		return __score_updated.value
	
	var __game_time_updated: PBField
	func has_game_time_updated() -> bool:
		if __game_time_updated.value != null:
			return true
		return false
	func get_game_time_updated() -> GameTimeUpdatedMessage:
		return __game_time_updated.value
	func clear_game_time_updated() -> void:
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_game_time_updated() -> GameTimeUpdatedMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		data[26].state = PB_SERVICE_STATE.FILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = GameTimeUpdatedMessage.new()
		return __game_time_updated.value
	
	var __aim_input: PBField
	func has_aim_input() -> bool:
		if __aim_input.value != null:
			return true
		return false
	func get_aim_input() -> AimInputMessage:
		return __aim_input.value
	func clear_aim_input() -> void:
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_aim_input() -> AimInputMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		data[27].state = PB_SERVICE_STATE.FILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = AimInputMessage.new()
		return __aim_input.value
	
	var __player_aim_updated: PBField
	func has_player_aim_updated() -> bool:
		if __player_aim_updated.value != null:
			return true
		return false
	func get_player_aim_updated() -> PlayerAimUpdatedMessage:
		return __player_aim_updated.value
	func clear_player_aim_updated() -> void:
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_player_aim_updated() -> PlayerAimUpdatedMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		data[28].state = PB_SERVICE_STATE.FILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = PlayerAimUpdatedMessage.new()
		return __player_aim_updated.value
	
	var __shoot_request: PBField
	func has_shoot_request() -> bool:
		if __shoot_request.value != null:
			return true
		return false
	func get_shoot_request() -> ShootRequestMessage:
		return __shoot_request.value
	func clear_shoot_request() -> void:
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_shoot_request() -> ShootRequestMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		data[29].state = PB_SERVICE_STATE.FILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = ShootRequestMessage.new()
		return __shoot_request.value
	
	var __bullet_spawned: PBField
	func has_bullet_spawned() -> bool:
		if __bullet_spawned.value != null:
			return true
		return false
	func get_bullet_spawned() -> BulletSpawnedMessage:
		return __bullet_spawned.value
	func clear_bullet_spawned() -> void:
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_bullet_spawned() -> BulletSpawnedMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		data[30].state = PB_SERVICE_STATE.FILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = BulletSpawnedMessage.new()
		return __bullet_spawned.value
	
	var __bullet_hit: PBField
	func has_bullet_hit() -> bool:
		if __bullet_hit.value != null:
			return true
		return false
	func get_bullet_hit() -> BulletHitMessage:
		return __bullet_hit.value
	func clear_bullet_hit() -> void:
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_bullet_hit() -> BulletHitMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		data[31].state = PB_SERVICE_STATE.FILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = BulletHitMessage.new()
		return __bullet_hit.value
	
	var __skill_request: PBField
	func has_skill_request() -> bool:
		if __skill_request.value != null:
			return true
		return false
	func get_skill_request() -> SkillRequestMessage:
		return __skill_request.value
	func clear_skill_request() -> void:
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_skill_request() -> SkillRequestMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		data[32].state = PB_SERVICE_STATE.FILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = SkillRequestMessage.new()
		return __skill_request.value
	
	var __skill_activated: PBField
	func has_skill_activated() -> bool:
		if __skill_activated.value != null:
			return true
		return false
	func get_skill_activated() -> SkillActivatedMessage:
		return __skill_activated.value
	func clear_skill_activated() -> void:
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_skill_activated() -> SkillActivatedMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		data[33].state = PB_SERVICE_STATE.FILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = SkillActivatedMessage.new()
		return __skill_activated.value
	
	var __player_healed: PBField
	func has_player_healed() -> bool:
		if __player_healed.value != null:
			return true
		return false
	func get_player_healed() -> PlayerHealedMessage:
		return __player_healed.value
	func clear_player_healed() -> void:
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_player_healed() -> PlayerHealedMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		data[34].state = PB_SERVICE_STATE.FILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = PlayerHealedMessage.new()
		return __player_healed.value
	
	var __molotov_spawned: PBField
	func has_molotov_spawned() -> bool:
		if __molotov_spawned.value != null:
			return true
		return false
	func get_molotov_spawned() -> MolotovSpawnedMessage:
		return __molotov_spawned.value
	func clear_molotov_spawned() -> void:
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_molotov_spawned() -> MolotovSpawnedMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		data[35].state = PB_SERVICE_STATE.FILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = MolotovSpawnedMessage.new()
		return __molotov_spawned.value
	
	var __skill_damage: PBField
	func has_skill_damage() -> bool:
		if __skill_damage.value != null:
			return true
		return false
	func get_skill_damage() -> SkillDamageMessage:
		return __skill_damage.value
	func clear_skill_damage() -> void:
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_skill_damage() -> SkillDamageMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		data[36].state = PB_SERVICE_STATE.FILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = SkillDamageMessage.new()
		return __skill_damage.value
	
	var __player_died: PBField
	func has_player_died() -> bool:
		if __player_died.value != null:
			return true
		return false
	func get_player_died() -> PlayerDiedMessage:
		return __player_died.value
	func clear_player_died() -> void:
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_player_died() -> PlayerDiedMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		data[37].state = PB_SERVICE_STATE.FILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = PlayerDiedMessage.new()
		return __player_died.value
	
	var __player_respawned: PBField
	func has_player_respawned() -> bool:
		if __player_respawned.value != null:
			return true
		return false
	func get_player_respawned() -> PlayerRespawnedMessage:
		return __player_respawned.value
	func clear_player_respawned() -> void:
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_player_respawned() -> PlayerRespawnedMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		data[38].state = PB_SERVICE_STATE.FILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = PlayerRespawnedMessage.new()
		return __player_respawned.value
	
	var __match_ended: PBField
	func has_match_ended() -> bool:
		if __match_ended.value != null:
			return true
		return false
	func get_match_ended() -> MatchEndedMessage:
		return __match_ended.value
	func clear_match_ended() -> void:
		data[39].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_match_ended() -> MatchEndedMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		data[39].state = PB_SERVICE_STATE.FILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = MatchEndedMessage.new()
		return __match_ended.value
	
	var __request_return_to_lobby: PBField
	func has_request_return_to_lobby() -> bool:
		if __request_return_to_lobby.value != null:
			return true
		return false
	func get_request_return_to_lobby() -> RequestReturnToLobbyMessage:
		return __request_return_to_lobby.value
	func clear_request_return_to_lobby() -> void:
		data[40].state = PB_SERVICE_STATE.UNFILLED
		__request_return_to_lobby.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_request_return_to_lobby() -> RequestReturnToLobbyMessage:
		__chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ok_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__error_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_general_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__response_user_stats.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__response_user_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__response_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__request_update_user_skin.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__request_enter_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__request_leave_queue.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__queue_joined.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__queue_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__match_found.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__spawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__despawn_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__movement_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__player_moved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__player_health_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__spawn_flag.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__flag_state_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__score_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__game_time_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__aim_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__player_aim_updated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__shoot_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__bullet_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__bullet_hit.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__skill_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__skill_activated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__player_healed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__molotov_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		__skill_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[37].state = PB_SERVICE_STATE.UNFILLED
		__player_respawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[38].state = PB_SERVICE_STATE.UNFILLED
		__match_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[39].state = PB_SERVICE_STATE.UNFILLED
		data[40].state = PB_SERVICE_STATE.FILLED
		__request_return_to_lobby.value = RequestReturnToLobbyMessage.new()
		return __request_return_to_lobby.value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
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
