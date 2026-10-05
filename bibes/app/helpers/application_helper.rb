module ApplicationHelper
  # Inline icon path data and license notices are recorded in THIRD_PARTY_NOTICES.md.
  LUCIDE_ICONS = {
    dashboard: '<rect width="7" height="9" x="3" y="3" rx="1"/><rect width="7" height="5" x="14" y="3" rx="1"/><rect width="7" height="9" x="14" y="12" rx="1"/><rect width="7" height="5" x="3" y="16" rx="1"/>',
    boxes: '<path d="m12 3 9 5-9 5-9-5 9-5Z"/><path d="m3 12 9 5 9-5"/><path d="m3 16 9 5 9-5"/>',
    database: '<ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M3 5v14a9 3 0 0 0 18 0V5"/><path d="M3 12a9 3 0 0 0 18 0"/>',
    plus: '<path d="M12 5v14"/><path d="M5 12h14"/>',
    arrow_up_right: '<path d="M7 7h10v10"/><path d="M7 17 17 7"/>',
    arrow_right: '<path d="M5 12h14"/><path d="m12 5 7 7-7 7"/>',
    arrow_left: '<path d="M19 12H5"/><path d="m12 19-7-7 7-7"/>',
    check: '<path d="m20 6-11 11-5-5"/>'
  }.freeze

  def lucide_icon(name, size: 16, class_name: nil)
    content_tag(
      :svg,
      raw(LUCIDE_ICONS.fetch(name.to_sym)),
      xmlns: "http://www.w3.org/2000/svg",
      width: size,
      height: size,
      viewBox: "0 0 24 24",
      fill: "none",
      stroke: "currentColor",
      "stroke-width": 2,
      "stroke-linecap": "round",
      "stroke-linejoin": "round",
      "aria-hidden": true,
      class: [ "icon", class_name ].compact.join(" ")
    )
  end
end
