// ignore: lines_longer_than_80_chars

enum NrfDfuObjType {
  invalid(description: 'NRF_DFU_OBJ_TYPE_INVALID'),
  command(description: 'NRF_DFU_OBJ_TYPE_COMMAND'),
  data(description: 'NRF_DFU_OBJ_TYPE_DATA');

  const NrfDfuObjType({required this.description});

  final String description;
}

enum NrfDfuTransferType {
  init(code: 0x01, description: 'Transfer of an init packet'),
  image(code: 0x02, description: 'Transfer of a firmware image');

  const NrfDfuTransferType({
    required this.code,
    required this.description,
  });

  final int code;
  final String description;
}

enum NrfDfuOp {
  protocolVersion(code: 0x00, description: 'NRF_DFU_OP_PROTOCOL_VERSION'),
  objectCreate(code: 0x01, description: 'NRF_DFU_OP_OBJECT_CREATE'),
  receiptNotifSet(
      code: 0x02, description: 'NRF_DFU_OP_RECEIPT_NOTIF_SET'),
  crcGet(code: 0x03, description: 'NRF_DFU_OP_CRC_GET'),
  objectExecute(
      code: 0x04, description: 'NRF_DFU_OP_OBJECT_EXECUTE'),
  objectSelect(code: 0x06, description: 'NRF_DFU_OP_OBJECT_SELECT'),
  mtuGet(code: 0x07, description: 'NRF_DFU_OP_MTU_GET'),
  objectWrite(
      code: 0x08, description: 'NRF_DFU_OP_OBJECT_WRITE'),
  ping(code: 0x09, description: 'NRF_DFU_OP_PING'),
  hardwareVersion(code: 0x0a, description: 'NRF_DFU_OP_HARDWARE_VERSION'),
  firmwareVersion(code: 0x0b, description: 'NRF_DFU_OP_FIRMWARE_VERSION'),
  abort(code: 0x0c, description: 'NRF_DFU_OP_ABORT'),
  response(code: 0x60, description: 'NRF_DFU_OP_RESPONSE');

  const NrfDfuOp({
    required this.code,
    required this.description,
  });

  final int code;
  final String description;
}

enum NrfDfuResult {
  invalid(code: 0x00, description: 'NRF_DFU_RES_CODE_INVALID'),
  success(code: 0x01, description: 'NRF_DFU_RES_CODE_SUCCESS'),
  notSupported(
      code: 0x02, description: 'NRF_DFU_RES_CODE_OP_CODE_NOT_SUPPORTED'),
  invalidParameter(
      code: 0x03, description: 'NRF_DFU_RES_CODE_INVALID_PARAMETER'),
  insufficientResources(
      code: 0x04, description: 'NRF_DFU_RES_CODE_INSUFFICIENT_RESOURCES'),
  invalidObject(code: 0x05, description: 'NRF_DFU_RES_CODE_INVALID_OBJECT'),
  notSupportedType(
      code: 0x07, description: 'NRF_DFU_RES_CODE_UNSUPPORTED_TYPE'),
  operationNotPermitted(
      code: 0x08, description: 'NRF_DFU_RES_CODE_OPERATION_NOT_PERMITTED'),
  operationFailed(code: 0x0a, description: 'NRF_DFU_RES_CODE_OPERATION_FAILED'),
  extError(code: 0x0b, description: 'NRF_DFU_RES_CODE_EXT_ERROR');

  const NrfDfuResult({
    required this.code,
    required this.description,
  });

  final int code;
  final String description;
}
