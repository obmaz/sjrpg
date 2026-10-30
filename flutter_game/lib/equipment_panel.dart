import 'package:flutter/material.dart';

import 'adventure.dart';
import 'combat_balance.dart';
import 'combat_distance.dart';
import 'combat_numbers.dart';
import 'game_ui.dart';
import 'panel_controls.dart';
import 'rpg_model.dart';
import 'rpg_widgets.dart';
import 'shop_content.dart';

const _muted = Color(0xffa4bcb6);
const _mint = Color(0xff8ce6c5);
String _slotName(GearSlot slot) => ['무기', '방어구', '부적'][slot.index];

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
  final bagScroll = ScrollController(), shopScroll = ScrollController();
  int bagTab = 0, shopTab = 0;
  Gear? detail;
  _Offer? offer;
  String message = '';
  String? feedbackOffer;
  int? pinnedGear;
  Set<int> newTabItems = {};
  Adventure get s => widget.session;
  Progress get p => s.progress;
  double get _frenzyTempo => s.hero.frenzyTime > 0 ? p.frenzyAttackTempo : 1;
  double get _currentBasicDps => p
      .basicAttackStats(
        frenzyTempo: _frenzyTempo,
        attackTempo: s.afflictions.attackTempo,
      )
      .dps;
  BasicAttackStats? _previewBasicAttack(Gear gear) => p.previewBasicAttack(
    gear,
    frenzyTempo: _frenzyTempo,
    attackTempo: s.afflictions.attackTempo,
  );
  @override
  void initState() {
    super.initState();
    if (!shopping) _showNewGear();
  }

  void _showNewGear() {
    if (p.unseenGear.isEmpty) return;
    bagTab = 1;
    newTabItems = {...p.unseenGear};
    detail = null;
    pinnedGear = null;
    if (bagScroll.hasClients) bagScroll.jumpTo(0);
  }

  @override
  void dispose() {
    bagScroll.dispose();
    shopScroll.dispose();
    super.dispose();
  }

  void inspect(Gear gear, {bool equipped = false}) {
    setState(() {
      p.unseenGear.remove(gear.serial);
      detail = detail == gear && !equipped ? null : gear;
      offer = null;
      if (equipped) {
        bagTab = 0;
        pinnedGear = gear.serial;
      }
    });
    if (equipped && bagScroll.hasClients) bagScroll.jumpTo(0);
    s.refresh();
  }

  void tab(int index) => setState(() {
    if (shopping) {
      shopTab = index;
      if (shopScroll.hasClients) shopScroll.jumpTo(0);
    } else {
      bagTab = index;
      pinnedGear = null;
      detail = null;
      if (index == 1) newTabItems = {...p.unseenGear};
      if (bagScroll.hasClients) bagScroll.jumpTo(0);
    }
  });
  @override
  Widget build(BuildContext context) {
    final shortScreen = MediaQuery.sizeOf(context).height < 500;
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
                child: Column(
                  children: [
                    _header(dense: shortScreen),
                    GameTabs(
                      shopping
                          ? ['무기', '방어구', '부적', '물약', '축복']
                          : ['전체', '신규', '무기', '방어구', '부적', '잠금'],
                      shopping ? shopTab : bagTab,
                      tab,
                      flat: true,
                    ),
                    Expanded(child: shopping ? _store() : _inventory()),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        12,
                        shortScreen ? 4 : 8,
                        12,
                        8,
                      ),
                      child: Row(
                        children: [
                          if (widget.startInShop) ...[
                            Expanded(
                              child: GameAction(
                                shopping ? '가방' : '상점',
                                minHeight: shortScreen ? 44 : 50,
                                icon: shopping
                                    ? Icons.backpack_outlined
                                    : Icons.storefront,
                                onTap: () => setState(() {
                                  shopping = !shopping;
                                  if (!shopping) _showNewGear();
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
                              minHeight: shortScreen ? 44 : 50,
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
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header({bool dense = false}) => GamePanelHeader(
    dense: dense,
    title: shopping ? '상점' : '장비 가방',
    subtitle:
        '${shopping ? p.heroClass.title : '보관함'} · ${p.inventory.length}/${Progress.capacity}',
    onClose: widget.onClose,
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
    final items = p.inventory.reversed
        .where(
          (g) =>
              bagTab == 0 ||
              (bagTab == 1
                  ? newTabItems.contains(g.serial) ||
                        p.unseenGear.contains(g.serial)
                  : bagTab == 5
                  ? g.locked || detail == g
                  : g.base.slot.index == bagTab - 2),
        )
        .toList();
    final pinned = items.indexWhere((g) => g.serial == pinnedGear);
    if (pinned > 0) items.insert(0, items.removeAt(pinned));
    return _scroller(
      bagScroll,
      CustomScrollView(
        controller: bagScroll,
        key: const PageStorageKey('equipment-list'),
        physics: const ClampingScrollPhysics(),
        slivers: [
          if (bagTab != 1)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              sliver: SliverToBoxAdapter(child: _equipmentOverview()),
            ),

          if (items.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  bagTab == 1
                      ? '확인하지 않은 새 장비가 없습니다'
                      : bagTab == 5
                      ? '잠근 장비가 없습니다'
                      : '이 부위에 보관한 장비가 없습니다',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted, fontSize: 14),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            sliver: SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, i) => _gearRow(items[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _equipmentOverview() => ConstrainedBox(
    key: const ValueKey('equipment-overview'),
    constraints: const BoxConstraints(minHeight: 56),
    child: Row(
      children: [
        for (final slot in GearSlot.values) ...[
          SizedBox.square(
            key: ValueKey('equipped-slot-${slot.name}'),
            dimension: 44,
            child: Tooltip(
              message:
                  '${_slotName(slot)} · ${p.equipped[slot]?.name ?? '비어 있음'}',
              excludeFromSemantics: true,
              child: _gearCell(p.equipped[slot], equippedSlot: slot),
            ),
          ),
          const SizedBox(width: 4),
        ],
        const SizedBox(width: 4),
        Expanded(
          child: Wrap(
            spacing: 10,
            runSpacing: 2,
            children: [
              for (final pair in [
                ('공격력', p.swordDamage),
                ('방어', p.armor),
                ('생명', p.maxHp),
              ])
                Text(
                  '${pair.$1} ${CombatNumbers.stat(pair.$2)}',
                  style: const TextStyle(
                    color: cream,
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  String _gearAccessibilityStats(Gear gear) {
    final current = p.equipped[gear.base.slot];
    if (gear.base.slot == GearSlot.weapon) {
      final attack = _previewBasicAttack(gear);
      return '무기 레벨 ${gear.weaponLevel} · 무기 공격 ${CombatNumbers.stat(gear.attack)} · 기본 공격 1타 ${attack == null ? '직업 제한' : CombatNumbers.stat(attack.damage)} · 사거리 ${CombatDistance.format(gear.base.range)} · 초당 피해 ${attack == null ? '직업 제한' : CombatNumbers.stat(attack.dps)} · 현재 초당 피해 ${CombatNumbers.stat(_currentBasicDps)}';
    }
    return '방어 ${CombatNumbers.stat(gear.armor)} · 생명 ${CombatNumbers.stat(gear.health)} · ${p.heroClass.resource} ${CombatNumbers.resource(gear.mana)} · 현재 방어 ${CombatNumbers.stat(current?.armor ?? 0)} · 현재 생명 ${CombatNumbers.stat(current?.health ?? 0)}';
  }

  Widget _gearCell(Gear? gear, {GearSlot? equippedSlot}) {
    final active = gear != null && p.isEquipped(gear),
        color = gear == null
            ? const Color(0xff34534b)
            : Color(gear.rarity.color);
    return Semantics(
      container: true,
      button: gear != null,
      hint: gear == null ? null : _gearAccessibilityStats(gear),
      label: gear == null
          ? '빈 ${equippedSlot == null ? '' : '${_slotName(equippedSlot)} '}장비 칸'
          : '${equippedSlot != null ? '착용 ${_slotName(equippedSlot)} · ' : '보관 장비 · '}${gear.name}${active ? ' · 장착 중' : ''}${gear.locked ? ' · 잠금' : ''}${p.unseenGear.contains(gear.serial) ? ' · 신규' : ''}',
      excludeSemantics: true,
      onTap: gear == null
          ? null
          : () => inspect(gear, equipped: equippedSlot != null),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: gear == null
              ? null
              : () => inspect(gear, equipped: equippedSlot != null),
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
                                : equippedSlot == GearSlot.charm
                                ? Icons.diamond_outlined
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
                if (gear?.weaponLevel != null)
                  Positioned(
                    left: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 1,
                      ),
                      color: const Color(0xdd0b2525),
                      child: Text(
                        'Lv.${gear!.weaponLevel}',
                        style: const TextStyle(color: cream, fontSize: 10),
                      ),
                    ),
                  ),
                if (active || gear?.locked == true)
                  Positioned(
                    right: 3,
                    top: 3,
                    child: Icon(
                      gear?.locked == true
                          ? Icons.lock_rounded
                          : Icons.check_circle,
                      color: gear?.locked == true ? gold : _mint,
                      size: 14,
                    ),
                  ),
                if (gear != null &&
                    !active &&
                    !gear.locked &&
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_Offer> get offers {
    if (shopTab == 3) {
      return [
        _Offer(
          'heal',
          '치유 물약 ×${CombatBalance.potionBundleSize}',
          '생명 ${CombatNumbers.stat(CombatBalance.potionHealing)} 회복 · 보유 ${p.healingPotions}개',
          CombatBalance.healingPotionPrice,
        ),
        _Offer(
          'energy',
          '${p.heroClass.resource} 물약 ×${CombatBalance.potionBundleSize}',
          '${p.heroClass.resource} ${CombatNumbers.resource(CombatBalance.potionEnergy)} 회복 · 보유 ${p.energyPotions}개',
          CombatBalance.resourcePotionPrice,
        ),
      ];
    }
    if (shopTab == 4) {
      return [
        _Offer(
          'power',
          '무기 강화',
          '공격력 +${CombatNumbers.stat(p.attackTrainingGain)} · 수련 ${p.attackTrainingRank}/${p.maxTrainingRank}',
          p.attackTrainingCost,
        ),
        _Offer(
          'vitality',
          '생명 축복',
          '최대 생명 +${CombatNumbers.stat(20)} · 수련 ${p.vitalityTrainingRank}/${p.maxTrainingRank}',
          p.vitalityTrainingCost,
        ),
      ];
    }
    final stock = s.shopGearOffers.where(
      (offer) => offer.base.slot == GearSlot.values[shopTab],
    );
    return [
      for (final offer in stock)
        _Offer(
          offer.base.id,
          offer.preview.name,
          offer.preview.stats,
          offer.price,
          gear: offer,
        ),
    ];
  }

  Widget _store() {
    final entries = offers;
    return _scroller(
      shopScroll,
      ListView.builder(
        controller: shopScroll,
        key: const PageStorageKey('merchant-list'),
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(8),
        itemCount: entries.length,
        itemBuilder: (context, i) {
          final entry = entries[i];
          return entry.gear == null
              ? _consumableRow(entry)
              : _gearRow(entry.gear!.preview, entry: entry);
        },
      ),
    );
  }

  Widget _offerArt(_Offer entry) => entry.gear != null
      ? CustomPaint(
          size: const Size.square(100),
          painter: GearGlyph(entry.gear!.preview, s.art),
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

  bool _sameEquippedOffer(_Offer entry) {
    final offer = entry.gear;
    final current = offer == null ? null : p.equipped[offer.base.slot];
    return current != null && offer!.matches(current);
  }

  Widget _gearRow(Gear gear, {_Offer? entry}) {
    final owned = entry == null, active = owned && p.isEquipped(gear);
    final expanded = owned ? detail == gear : offer?.id == entry.id;
    final current = p.equipped[gear.base.slot];
    final color = Color(gear.rarity.color);
    final full = !owned && p.inventory.length >= Progress.capacity;
    final poor = !owned && p.gold < entry.price;
    final already = !owned && _sameEquippedOffer(entry);
    final usable = gear.base.usable(p.heroClass);
    final attack = usable && gear.base.slot == GearSlot.weapon
        ? _previewBasicAttack(gear)
        : null;
    final label = owned
        ? '보관 장비 · ${gear.name}${active ? ' · 장착 중' : ''}${gear.locked ? ' · 잠금' : ''}${p.unseenGear.contains(gear.serial) ? ' · 신규' : ''}'
        : '${entry.title} · ${entry.price} 골드';
    void select() {
      if (owned) {
        inspect(gear);
      } else {
        setState(() {
          offer = expanded ? null : entry;
          detail = null;
        });
      }
    }

    return Container(
      key: owned
          ? ValueKey('gear-row-${gear.serial}')
          : ValueKey('offer-${entry.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            expanded ? const Color(0xff28483c) : const Color(0xff153a33),
            const Color(0xff0d2827),
          ],
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: expanded ? gold : const Color(0xff36574c),
          width: expanded ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  container: true,
                  button: true,
                  label: label,
                  hint: _gearAccessibilityStats(gear),
                  onTap: select,
                  excludeSemantics: true,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: select,
                      borderRadius: BorderRadius.circular(9),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              key: ValueKey('gear-icon-${gear.serial}'),
                              width: 48,
                              height: 58,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: .1),
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: color.withValues(alpha: .7),
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: CustomPaint(
                                        painter: GearGlyph(gear, s.art),
                                      ),
                                    ),
                                  ),
                                  if (active || gear.locked)
                                    Positioned(
                                      right: 2,
                                      top: 2,
                                      child: Icon(
                                        gear.locked
                                            ? Icons.lock_rounded
                                            : Icons.check_circle,
                                        size: 15,
                                        color: gear.locked ? gold : _mint,
                                      ),
                                    ),
                                  if (owned &&
                                      p.unseenGear.contains(gear.serial))
                                    const Positioned(
                                      left: 3,
                                      top: 3,
                                      child: Icon(
                                        Icons.circle,
                                        color: gold,
                                        size: 8,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    gear.name,
                                    key: ValueKey('gear-title-${gear.serial}'),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${gear.rarity.title} · ${_slotName(gear.base.slot)}${gear.weaponLevel == null ? '' : ' · Lv.${gear.weaponLevel}'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 76,
                child: Column(
                  children: [
                    GameAction(
                      owned
                          ? active
                                ? '장착 중'
                                : usable
                                ? '장착'
                                : '직업 제한'
                          : already
                          ? '장착 중'
                          : '${entry.price} G',
                      key: owned
                          ? ValueKey('equip-${gear.serial}')
                          : ValueKey('buy-equip-${entry.id}'),
                      semanticLabel: owned
                          ? '${gear.name} 장착'
                          : '${entry.title} 구매 후 장착 · ${entry.price} 골드',
                      primary: true,
                      onTap: !usable || active || full || poor || already
                          ? null
                          : owned
                          ? () {
                              if (s.equip(gear)) setState(() {});
                            }
                          : () => purchase(entry, equip: true),
                    ),
                    if (!owned)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          full
                              ? '가방 가득'
                              : poor
                              ? '골드 부족'
                              : already
                              ? '사용 중'
                              : '구매·장착',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: _muted, fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (gear.base.slot != GearSlot.weapon && gear.attack > 0)
            _quickStat('장비 공격', gear.attack, current?.attack, active),
          if (gear.base.slot == GearSlot.charm &&
              gear.mana > 0 &&
              gear.armor > 0)
            _quickStat('방어', gear.armor, current?.armor, active),
          if (gear.base.slot == GearSlot.weapon) ...[
            _quickStat('무기 공격', gear.attack, current?.attack, active),
            if (attack != null)
              _quickStat(
                '기본 공격 1타',
                attack.damage,
                p.basicAttackStats().damage,
                active,
                decimal: true,
              ),
            if (attack != null)
              _quickStat(
                '초당 피해',
                attack.dps,
                _currentBasicDps,
                active,
                decimal: true,
              ),
          ] else if (gear.base.slot == GearSlot.armor) ...[
            _quickStat('방어', gear.armor, current?.armor, active),
            _quickStat('생명', gear.health, current?.health, active),
          ] else ...[
            _quickStat('생명', gear.health, current?.health, active),
            _quickStat(
              gear.mana > 0 || (current?.mana ?? 0) > 0
                  ? p.heroClass.resource
                  : '방어',
              gear.mana > 0 || (current?.mana ?? 0) > 0
                  ? gear.mana
                  : gear.armor,
              gear.mana > 0 || (current?.mana ?? 0) > 0
                  ? current?.mana
                  : current?.armor,
              active,
              unit: gear.mana > 0 || (current?.mana ?? 0) > 0
                  ? CombatUnit.resource
                  : CombatUnit.stat,
            ),
          ],
          if (gear.base.slot == GearSlot.weapon) ...[
            if (gear.armor > 0)
              _quickStat('방어', gear.armor, current?.armor, active),
            if (gear.health > 0)
              _quickStat('생명', gear.health, current?.health, active),
          ],
          if (gear.base.slot != GearSlot.charm && gear.mana > 0)
            _quickStat(
              p.heroClass.resource,
              gear.mana,
              current?.mana,
              active,
              unit: CombatUnit.resource,
            ),
          if (gear.base.haste > 0)
            _quickStat(
              '공격속도 %',
              gear.base.haste * 100,
              (current?.base.haste ?? 0) * 100,
              active,
              unit: null,
            ),
          if (gear.base.slot == GearSlot.weapon)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                '공격 주기 ${(attack?.interval ?? gear.base.tempo).toStringAsFixed(2)}초 · 사거리 ${CombatDistance.format(gear.base.range)}',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ),
          for (final ability in gear.gifts)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${ability.title} · ${ability.description}',
                style: const TextStyle(color: gold, fontSize: 12, height: 1.35),
              ),
            ),
          if (!owned && feedbackOffer == entry.id && message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                message,
                style: const TextStyle(color: _mint, fontSize: 14),
              ),
            ),
          if (expanded) ...[
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Divider(height: 1, color: Color(0xff36574c)),
            ),
            const SizedBox(height: 8),
            if (attack != null)
              Text(
                '기본 공격 1타 ${CombatNumbers.stat(attack.damage)} · 치명타 ${(attack.criticalChance * 100).toStringAsFixed(1)}%\n${CombatNumbers.stat(attack.damage)} × ${(1 + attack.criticalChance).toStringAsFixed(3)} ÷ ${attack.interval.toStringAsFixed(2)}초 ≈ 초당 ${CombatNumbers.stat(attack.dps)} 피해',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            if (attack != null)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                  '무기 공격은 장비 수치입니다. 기본 공격 1타는 레벨·숙련·기술 배율을 반영합니다. 초당 피해 = 1타 피해 × (1 + 치명타 확률) ÷ 공격 주기.',
                  style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
                ),
              ),
            if (owned)
              Row(
                children: [
                  Expanded(
                    child: GameAction(
                      gear.locked ? '잠금 해제' : '잠금',
                      semanticLabel:
                          '${gear.name} ${gear.locked ? '잠금 해제' : '잠금'}',
                      onTap: () {
                        p.setGearLocked(gear, !gear.locked);
                        s.refresh();
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GameAction(
                      gear.locked ? '잠긴 장비' : '${gear.saleValue} G 판매',
                      semanticLabel: '${gear.name} 판매 · ${gear.saleValue} 골드',
                      onTap: active || gear.locked
                          ? null
                          : () {
                              if (p.sell(gear)) {
                                s.refresh();
                                setState(() => detail = null);
                              }
                            },
                    ),
                  ),
                ],
              )
            else
              GameAction(
                '구매 후 가방에 보관',
                semanticLabel: '${entry.title} 구매 후 보관 · ${entry.price} 골드',
                onTap: full || poor ? null : () => purchase(entry),
              ),
            Align(
              alignment: Alignment.center,
              child: GameIconButton(
                label: '옵션 접기',
                onTap: select,
                icon: Icons.expand_less,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _quickStat(
    String label,
    double value,
    double? previous,
    bool active, {
    bool decimal = false,
    CombatUnit? unit = CombatUnit.stat,
  }) {
    final diff = value - (previous ?? 0);
    String number(double n) => unit == null
        ? (decimal ? n.toStringAsFixed(1) : '${n.round()}')
        : CombatNumbers.format(n, unit: unit);
    final hasDifference = unit == null
        ? diff.abs() > .01
        : CombatNumbers.value(diff, unit).abs() >= .5;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label ${number(value)}',
            style: const TextStyle(color: cream),
          ),
          if (!active && hasDifference)
            TextSpan(
              text: ' ${diff > 0 ? '↑ +' : '↓ '}${number(diff)}',
              style: TextStyle(
                color: diff > 0 ? _mint : const Color(0xffffa493),
              ),
            ),
        ],
      ),
      style: const TextStyle(fontSize: 14, height: 1.2),
    );
  }

  Widget _consumableRow(_Offer entry) {
    final capped =
        entry.id == 'power' && !p.canTrainAttack ||
        entry.id == 'vitality' && !p.canTrainVitality;
    return Container(
      key: ValueKey('offer-${entry.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff14372f),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xff36574c)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(width: 54, height: 68, child: _offerArt(entry)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: const TextStyle(
                        color: cream,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Semantics(
                      container: true,
                      label: entry.description,
                      excludeSemantics: true,
                      child: Text(
                        entry.description,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 76,
                child: GameAction(
                  capped ? '수련 완료' : '${entry.price} G',
                  primary: true,
                  semanticLabel: capped
                      ? '${entry.title} · 현재 레벨 수련 완료'
                      : '${entry.title} 구매 · ${entry.price} 골드',
                  onTap: capped || !s.canTrade || p.gold < entry.price
                      ? null
                      : () => purchase(entry),
                ),
              ),
            ],
          ),
          if (feedbackOffer == entry.id && message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                message,
                style: const TextStyle(color: _mint, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  void purchase(_Offer entry, {bool equip = false}) {
    if (equip && _sameEquippedOffer(entry)) return;
    Gear? bought;
    final success = entry.gear != null
        ? (bought = s.buyGear(entry.gear!.base, expectedPrice: entry.price)) !=
              null
        : switch (entry.id) {
            'heal' => s.buyHeal(),
            'energy' => s.buyEnergy(),
            'power' => s.buySword(expectedPrice: entry.price),
            'vitality' => s.buyVitality(expectedPrice: entry.price),
            _ => false,
          };
    if (!success) return;
    if (bought != null) {
      p.unseenGear.remove(bought.serial);
      if (equip) s.equip(bought);
    }
    setState(() {
      feedbackOffer = entry.id;
      message = equip ? '장착 완료 · ${entry.title}' : '구매 완료 · ${entry.title}';
    });
    s.refresh();
  }
}

class _Offer {
  const _Offer(this.id, this.title, this.description, this.price, {this.gear});
  final String id, title, description;
  final int price;
  final ShopGearOffer? gear;
}
