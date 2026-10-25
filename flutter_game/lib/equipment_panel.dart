import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'adventure.dart';
import 'game_ui.dart';
import 'rpg_model.dart';
import 'rpg_widgets.dart';

const _muted = Color(0xffa4bcb6);
const _mint = Color(0xff8ce6c5);
String _slotName(GearSlot slot) => ['무기', '방어구', '부적'][slot.index];

class GameAction extends StatelessWidget {
  const GameAction(
    this.label, {
    required this.onTap,
    this.primary = false,
    this.icon,
    super.key,
  });
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final shape = BeveledRectangleBorder(
      borderRadius: BorderRadius.circular(7),
      side: BorderSide(
        color: enabled
            ? (primary ? gold : const Color(0xff608b7c))
            : const Color(0xff37524c),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: SizedBox(
        height: 50,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: ShapeDecoration(
              shape: shape,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: !enabled
                    ? [const Color(0xff203a36), const Color(0xff162d2a)]
                    : primary
                    ? [const Color(0xffe5c881), const Color(0xffac7d3f)]
                    : [const Color(0xff214d45), const Color(0xff102d2a)],
              ),
            ),
            child: InkWell(
              customBorder: shape,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: 17,
                        color: primary && enabled
                            ? ink
                            : enabled
                            ? cream
                            : _muted,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: !enabled
                              ? _muted
                              : primary
                              ? ink
                              : cream,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs(this.labels, this.selected, this.onChange);
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChange;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < labels.length; i++)
        Expanded(
          child: Semantics(
            button: true,
            selected: selected == i,
            label: labels[i],
            excludeSemantics: true,
            onTap: () => onChange(i),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onChange(i),
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == i
                        ? const Color(0xff24483e)
                        : Colors.transparent,
                    border: Border(
                      bottom: BorderSide(
                        color: selected == i ? gold : const Color(0xff35554b),
                        width: selected == i ? 2 : 1,
                      ),
                    ),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 14,
                      color: selected == i ? gold : _muted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class EquipmentPanel extends StatefulWidget {
  const EquipmentPanel({
    required this.session,
    required this.onClose,
    this.startInShop = false,
    super.key,
  });
  final Adventure session;
  final VoidCallback onClose;
  final bool startInShop;
  @override
  State<EquipmentPanel> createState() => _EquipmentPanelState();
}

class _EquipmentPanelState extends State<EquipmentPanel> {
  late bool shopping = widget.startInShop;
  final bagScroll = ScrollController(),
      shopScroll = ScrollController(),
      detailScroll = ScrollController();
  int bagTab = 0, shopTab = 0;
  Gear? detail;
  _Offer? offer;
  String message = '';
  Adventure get s => widget.session;
  Progress get p => s.progress;
  @override
  void dispose() {
    bagScroll.dispose();
    shopScroll.dispose();
    detailScroll.dispose();
    super.dispose();
  }

  void inspect(Gear gear) => setState(() {
    p.unseenGear.remove(gear.serial);
    s.refresh();
    detail = gear;
    offer = null;
    message = '';
  });
  void dismissDetail() => setState(() {
    detail = null;
    offer = null;
    message = '';
  });
  void tab(int index) => setState(() {
    if (shopping) {
      shopTab = index;
      if (shopScroll.hasClients) shopScroll.jumpTo(0);
    } else {
      bagTab = index;
      if (bagScroll.hasClients) bagScroll.jumpTo(0);
    }
  });
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return ColoredBox(
      color: const Color(0xcc040d10),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: FramedSurface(
                art: s.art,
                compact: true,
                child: Stack(
                  children: [
                    Column(
                      children: [
                        _header(),
                        _Tabs(
                          shopping
                              ? ['장비', '물약', '축복']
                              : ['전체', '신규', '무기', '방어구', '부적'],
                          shopping ? shopTab : bagTab,
                          tab,
                        ),
                        Expanded(child: shopping ? _store() : _inventory()),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                          child: Row(
                            children: [
                              if (widget.startInShop) ...[
                                Expanded(
                                  child: GameAction(
                                    shopping ? '가방' : '상점',
                                    icon: shopping
                                        ? Icons.backpack_outlined
                                        : Icons.storefront,
                                    onTap: () => setState(() {
                                      shopping = !shopping;
                                      message = '';
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],
                              Expanded(
                                flex: 2,
                                child: GameAction(
                                  '모험 계속하기',
                                  primary: true,
                                  icon: Icons.play_arrow_rounded,
                                  onTap: widget.onClose,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (detail != null || offer != null) ...[
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: dismissDetail,
                          child: const ColoredBox(color: Color(0xb300080a)),
                        ),
                      ),
                      Align(
                        alignment: media.size.width > 700
                            ? Alignment.centerRight
                            : Alignment.bottomCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: 420,
                            maxHeight:
                                (media.size.height -
                                    media.padding.vertical -
                                    20) *
                                (media.size.height < 500 ? 1 : .84),
                          ),
                          child: _details(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xff0d2625),
            border: Border.all(color: gold.withValues(alpha: .6)),
          ),
          child: Icon(
            shopping ? Icons.storefront : Icons.shield_outlined,
            color: gold,
            size: 23,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shopping ? '숲길 상점' : '장비 가방',
                style: const TextStyle(
                  color: cream,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${shopping ? p.heroClass.title : '보관함'} · ${p.inventory.length}/${Progress.capacity}',
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            ],
          ),
        ),
        const Icon(Icons.monetization_on_rounded, size: 17, color: gold),
        const SizedBox(width: 4),
        Text(
          '${p.gold}',
          style: const TextStyle(
            color: gold,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          tooltip: '닫기',
          onPressed: widget.onClose,
          icon: const Icon(Icons.close, size: 21, color: _muted),
        ),
      ],
    ),
  );

  Widget _scroller(ScrollController controller, Widget child) => Scrollbar(
    controller: controller,
    thumbVisibility: true,
    thickness: 3,
    radius: const Radius.circular(3),
    child: ScrollConfiguration(
      behavior: const ScrollBehavior().copyWith(overscroll: false),
      child: child,
    ),
  );

  Widget _inventory() {
    final items = p.inventory
        .where(
          (g) =>
              bagTab == 0 ||
              (bagTab == 1
                  ? p.unseenGear.contains(g.serial)
                  : g.base.slot.index == bagTab - 2),
        )
        .toList();
    final count = bagTab == 0
        ? Progress.capacity
        : math.max(4, (items.length / 4).ceil() * 4);
    return _scroller(
      bagScroll,
      CustomScrollView(
        controller: bagScroll,
        key: const PageStorageKey('equipment-grid'),
        physics: const ClampingScrollPhysics(),
        slivers: [
          if (bagTab == 1 && items.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  '확인하지 않은 새 장비가 없습니다',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: 14),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  Row(
                    children: [
                      for (final slot in GearSlot.values)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 48,
                                  height: 58,
                                  child: _gearCell(
                                    p.equipped[slot],
                                    equippedSlot: slot,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    _slotName(slot),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final pair in [
                        ('공격', p.swordDamage),
                        ('방어', p.armor),
                        ('생명', p.maxHp),
                      ])
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xff102d29),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${pair.$1} ${pair.$2.round()}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: cream,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.crossAxisExtent > 460 ? 6 : 4;
                return SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _gearCell(index < items.length ? items[index] : null),
                    childCount: count,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: .87,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _gearCell(Gear? gear, {GearSlot? equippedSlot}) {
    final active = gear != null && p.isEquipped(gear),
        color = gear == null
            ? const Color(0xff34534b)
            : Color(gear.rarity.color);
    return Semantics(
      button: gear != null,
      label: gear == null
          ? '빈 장비 칸'
          : '${equippedSlot != null ? '착용 ${_slotName(equippedSlot)} · ' : '보관 장비 · '}${gear.name}${active ? ' · 장착 중' : ''}${p.unseenGear.contains(gear.serial) ? ' · 신규' : ''}',
      excludeSemantics: true,
      onTap: gear == null ? null : () => inspect(gear),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: gear == null ? null : () => inspect(gear),
          borderRadius: BorderRadius.circular(9),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              gradient: RadialGradient(
                center: const Alignment(0, -.25),
                radius: .85,
                colors: [
                  color.withValues(alpha: gear == null ? .04 : .18),
                  const Color(0xff0c2424),
                ],
              ),
              border: Border.all(
                color: color.withValues(alpha: gear == null ? .5 : .7),
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      6,
                      5,
                      6,
                      equippedSlot == null ? 20 : 5,
                    ),
                    child: gear == null
                        ? Icon(
                            equippedSlot == null
                                ? Icons.add
                                : Icons.shield_outlined,
                            size: 16,
                            color: const Color(0xff35544c),
                          )
                        : CustomPaint(painter: GearGlyph(gear, s.art)),
                  ),
                ),
                if (gear != null && equippedSlot == null)
                  Positioned(
                    left: 3,
                    right: 3,
                    bottom: 4,
                    child: Text(
                      gear.base.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: cream),
                    ),
                  ),
                if (active)
                  const Positioned(
                    right: 3,
                    top: 3,
                    child: Icon(Icons.check_circle, color: _mint, size: 14),
                  ),
                if (gear != null &&
                    !active &&
                    p.unseenGear.contains(gear.serial))
                  const Positioned(
                    right: 4,
                    top: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xffe6b75a),
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(width: 8, height: 8),
                    ),
                  ),
                if (gear != null && !active && _improvement(gear) > 0)
                  const Positioned(
                    left: 3,
                    top: 3,
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      color: _mint,
                      size: 16,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _improvement(Gear gear) {
    final current = p.equipped[gear.base.slot];
    if (current == null) return 1;
    return gear.base.slot == GearSlot.weapon
        ? gear.attack / gear.base.tempo - current.attack / current.base.tempo
        : gear.base.slot == GearSlot.armor
        ? gear.armor - current.armor
        : gear.health + gear.mana - current.health - current.mana;
  }

  List<_Offer> get offers {
    if (shopTab == 1) {
      return [
        _Offer('heal', '치유 물약 ×2', '생명 55 회복 · 보유 ${p.healingPotions}개', 20),
        _Offer(
          'energy',
          '${p.heroClass.resource} 물약 ×2',
          '${p.heroClass.resource} 60 회복 · 보유 ${p.energyPotions}개',
          18,
        ),
      ];
    }
    if (shopTab == 2) {
      return [
        const _Offer('power', '무기 강화', '현재 직업 공격력 +5', 45),
        const _Offer('vitality', '생명 축복', '최대 생명 +20 · 생명 회복', 60),
      ];
    }
    final stock = p.heroClass == HeroClass.warrior
        ? ['longsword', 'axe', 'spear', 'leather', 'chainmail', 'amber']
        : [
            'oakstaff',
            'frostwand',
            'stormrod',
            'silkrobe',
            'leather',
            'sapphire',
          ];
    return [
      for (final id in stock)
        _Offer(
          id,
          gearById(id).name,
          Gear(0, gearById(id)).stats,
          gearById(id).value,
          gear: gearById(id),
        ),
    ];
  }

  Widget _store() => _scroller(
    shopScroll,
    GridView.builder(
      controller: shopScroll,
      key: const PageStorageKey('merchant-grid'),
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(14),
      itemCount: offers.length,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio:
            MediaQuery.sizeOf(context).width > 600 &&
                MediaQuery.sizeOf(context).height < 500
            ? 1.65
            : .85,
      ),
      itemBuilder: (context, i) {
        final entry = offers[i];
        return Semantics(
          button: true,
          label: '${entry.title} · ${entry.price} 골드',
          excludeSemantics: true,
          onTap: () => setState(() {
            offer = entry;
            detail = null;
            message = '';
          }),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() {
                offer = entry;
                detail = null;
                message = '';
              }),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xff21463d), Color(0xff0e2927)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: gold.withValues(alpha: .35)),
                ),
                child: Column(
                  children: [
                    Expanded(child: _offerArt(entry)),
                    const SizedBox(height: 7),
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: cream,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.monetization_on_rounded,
                          color: gold,
                          size: 15,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${entry.price}',
                          style: const TextStyle(
                            color: gold,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _offerArt(_Offer entry) => entry.gear != null
      ? CustomPaint(
          size: const Size.square(100),
          painter: GearGlyph(Gear(0, entry.gear!), s.art),
        )
      : entry.id == 'heal' || entry.id == 'energy'
      ? Padding(
          padding: const EdgeInsets.all(6),
          child: CustomPaint(
            size: const Size(65, 85),
            painter: PotionPainter(s.art, blue: entry.id == 'energy'),
          ),
        )
      : CustomPaint(
          size: const Size.square(90),
          painter: EffectIconPainter(s.art, entry.id == 'power' ? 7 : 6),
        );

  Widget _details() {
    final gear = detail ?? (offer?.gear != null ? Gear(0, offer!.gear!) : null),
        entry = offer;
    final active = detail != null && p.isEquipped(detail!),
        current = gear == null ? null : p.equipped[gear.base.slot];
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xff0d2828),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gold.withValues(alpha: .65)),
        boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 22)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry != null
                        ? '상인에게 구매'
                        : active
                        ? '장착 중인 장비'
                        : '장비 비교',
                    style: const TextStyle(
                      color: gold,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '상세 닫기',
                  onPressed: dismissDetail,
                  icon: const Icon(Icons.close, color: _muted, size: 21),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xff3b584c)),
          Flexible(
            child: Scrollbar(
              controller: detailScroll,
              thumbVisibility: true,
              thickness: 3,
              child: SingleChildScrollView(
                controller: detailScroll,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 94,
                      child: gear != null
                          ? CustomPaint(painter: GearGlyph(gear, s.art))
                          : _offerArt(entry!),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      gear?.name ?? entry!.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: gear == null ? cream : Color(gear.rarity.color),
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      gear == null
                          ? entry!.id == 'heal'
                                ? '생명 55 회복 · 보유 ${p.healingPotions}개'
                                : entry.id == 'energy'
                                ? '${p.heroClass.resource} 60 회복 · 보유 ${p.energyPotions}개'
                                : entry.description
                          : '${gear.rarity.title} · ${_slotName(gear.base.slot)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                    if (message.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: _mint, fontSize: 14),
                        ),
                      ),
                    if (gear != null) ...[
                      const SizedBox(height: 16),
                      _stat('공격', gear.attack, current?.attack, active),
                      if (gear.base.slot == GearSlot.weapon)
                        _stat(
                          '초당 피해',
                          gear.attack / gear.base.tempo,
                          current == null
                              ? null
                              : current.attack / current.base.tempo,
                          active,
                          decimal: true,
                        ),
                      _stat('방어', gear.armor, current?.armor, active),
                      _stat('생명', gear.health, current?.health, active),
                      _stat('마나', gear.mana, current?.mana, active),
                      if (gear.base.haste > 0)
                        _stat(
                          '공격속도 %',
                          gear.base.haste * 100,
                          (current?.base.haste ?? 0) * 100,
                          active,
                        ),
                      if (gear.base.slot == GearSlot.weapon)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            '공격 주기 ${gear.base.tempo.toStringAsFixed(2)}초 · 사거리 ${gear.base.range.round()}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: _muted, fontSize: 13),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: entry != null
                ? GameAction(
                    p.inventory.length >= Progress.capacity &&
                            entry.gear != null
                        ? '가방이 가득 찼습니다'
                        : p.gold < entry.price
                        ? '골드가 부족합니다'
                        : '${entry.price} G · 구매',
                    primary: true,
                    icon: Icons.monetization_on_rounded,
                    onTap:
                        p.gold < entry.price ||
                            (entry.gear != null &&
                                p.inventory.length >= Progress.capacity)
                        ? null
                        : purchase,
                  )
                : Row(
                    children: [
                      Expanded(
                        child: GameAction(
                          active ? '장착 중' : '장착',
                          primary: true,
                          icon: Icons.shield_outlined,
                          onTap: active || !gear!.base.usable(p.heroClass)
                              ? null
                              : () {
                                  s.equip(gear);
                                  setState(() => message = '장착했습니다');
                                },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GameAction(
                          '판매 +${gear!.saleValue} G',
                          icon: Icons.sell_outlined,
                          onTap: active
                              ? null
                              : () {
                                  if (!p.sell(gear)) return;
                                  s.refresh();
                                  dismissDetail();
                                },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _stat(
    String label,
    double value,
    double? previous,
    bool active, {
    bool decimal = false,
  }) {
    if (value == 0 && (previous ?? 0) == 0) return const SizedBox.shrink();
    final diff = value - (previous ?? 0), changed = !active && diff.abs() > .01;
    String number(double n) => decimal ? n.toStringAsFixed(1) : '${n.round()}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: _muted, fontSize: 15),
            ),
          ),
          Text(
            number(value),
            style: const TextStyle(
              color: cream,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (changed)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                '${diff > 0 ? '↑ +' : '↓ '}${number(diff)}',
                style: TextStyle(
                  color: diff > 0 ? _mint : const Color(0xffffa493),
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void purchase() {
    final entry = offer;
    if (entry == null) return;
    Gear? bought;
    final success = entry.gear != null
        ? (bought = s.buyGear(entry.gear!)) != null
        : switch (entry.id) {
            'heal' => s.buyHeal(),
            'energy' => s.buyEnergy(),
            'power' => s.buySword(),
            'vitality' => s.buyVitality(),
            _ => false,
          };
    if (!success) return;
    s.refresh();
    if (detailScroll.hasClients) detailScroll.jumpTo(0);
    setState(() {
      message = '구매 완료 · ${entry.title}';
      if (bought != null) {
        p.unseenGear.remove(bought.serial);
        detail = bought;
        offer = null;
      }
    });
  }
}

class _Offer {
  const _Offer(this.id, this.title, this.description, this.price, {this.gear});
  final String id, title, description;
  final int price;
  final GearDef? gear;
}
