import 'package:flutter/material.dart';

const _tagColorPairs = [
  (bg: Color(0xFFEDE9FE), fg: Color(0xFF5B21B6)), // Violet
  (bg: Color(0xFFDCFCE7), fg: Color(0xFF14532D)), // Green
  (bg: Color(0xFFFEF3C7), fg: Color(0xFF78350F)), // Amber
  (bg: Color(0xFFFFEDD5), fg: Color(0xFF7C2D12)), // Orange
  (bg: Color(0xFFE0F2FE), fg: Color(0xFF0C4A6E)), // Sky
  (bg: Color(0xFFFCE7F3), fg: Color(0xFF831843)), // Pink
  (bg: Color(0xFFF1F5F9), fg: Color(0xFF334155)), // Slate
];

/// タグ名からハッシュで自動割り当て。同じタグ名は常に同じ色。
({Color bg, Color fg}) tagColor(String name) =>
    _tagColorPairs[name.hashCode.abs() % _tagColorPairs.length];
