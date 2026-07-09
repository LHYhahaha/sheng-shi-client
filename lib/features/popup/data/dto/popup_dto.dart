import '../../../../core/network/json_field_parser.dart';
import '../../domain/popup.dart';

class PopupDto {
  const PopupDto({
    this.id,
    this.name,
    this.placementCode,
    this.contentMode,
    this.popupImage,
    this.showCloseButton,
    this.jumpType,
    this.h5Url,
    this.pageCode,
    this.shortJumpMode,
    this.shortDramaId,
    this.frontPopupLimit,
  });

  final int? id;
  final String? name;
  final String? placementCode;
  final int? contentMode;
  final String? popupImage;
  final int? showCloseButton;
  final int? jumpType;
  final String? h5Url;
  final String? pageCode;
  final int? shortJumpMode;
  final int? shortDramaId;
  final int? frontPopupLimit;

  factory PopupDto.fromJson(Map<String, Object?> json) {
    return PopupDto(
      id: JsonFieldParser.optionalInt(json, 'id'),
      name: JsonFieldParser.optionalString(json, 'name'),
      placementCode: JsonFieldParser.optionalString(json, 'placement_code'),
      contentMode: JsonFieldParser.optionalInt(json, 'content_mode'),
      popupImage: JsonFieldParser.optionalString(json, 'popup_image'),
      showCloseButton: JsonFieldParser.optionalInt(json, 'show_close_button'),
      jumpType: JsonFieldParser.optionalInt(json, 'jump_type'),
      h5Url: JsonFieldParser.optionalString(json, 'h5_url'),
      pageCode: JsonFieldParser.optionalString(json, 'page_code'),
      shortJumpMode: JsonFieldParser.optionalInt(json, 'short_jump_mode'),
      shortDramaId: JsonFieldParser.optionalInt(json, 'short_drama_id'),
      frontPopupLimit: JsonFieldParser.optionalInt(json, 'front_popup_limit'),
    );
  }

  PopupConfig toDomain() {
    return PopupConfig(
      id: id,
      name: name,
      placementCode: placementCode,
      contentMode: contentMode,
      popupImage: popupImage,
      showCloseButton: showCloseButton,
      jumpType: jumpType,
      h5Url: h5Url,
      pageCode: pageCode,
      shortJumpMode: shortJumpMode,
      shortDramaId: shortDramaId,
      frontPopupLimit: frontPopupLimit,
    );
  }
}
