import 'package:flutter/material.dart';

import 'adventure.dart';
import 'game_ui.dart';
import 'panel_controls.dart';
import 'rpg_model.dart';
import 'rpg_widgets.dart';

const _muted = Color(0xffa4bcb6);
const _mint = Color(0xff8ce6c5);

/// Weapon selection, outcome and purchase live in one mobile sheet.
class BlacksmithPanel extends StatefulWidget {
  const BlacksmithPanel({
    required this.session,
    required this.onClose,
    this.onCheckpoint,
    super.key,
  });
  final Adventure session;
  final VoidCallback onClose;
  final VoidCallback? onCheckpoint;
  @override
  State<BlacksmithPanel> createState() => _BlacksmithPanelState();
}

class _BlacksmithPanelState extends State<BlacksmithPanel> {
  final weaponsScroll = ScrollController(), detailScroll = ScrollController();
  int? selectedSerial;
  String message = '';
  bool destroyed = false;
  Adventure get s => widget.session;
  @override
  void initState() {
    super.initState();
    final equipped = s.progress.equipped[GearSlot.weapon];
    if (equipped != null) selectedSerial = equipped.serial;
  }

  @override
  void dispose() {
    weaponsScroll.dispose();
    detailScroll.dispose();
    super.dispose();
  }

  Gear? get selected => s.progress.inventory
      .where((gear) => gear.serial == selectedSerial)
      .firstOrNull;

  void enhance(SmithQuote quote) {
    final gear = selected;
    if (gear == null || gear.serial != quote.serial) return;
    // Submit exactly the cost/chance that was displayed, never silently requote.
    final result = s.enhanceWeapon(quote);
    if (result == null) {
      setState(() {
        message = '상태가 바뀌었습니다. 내용을 확인한 뒤 다시 시도하세요.';
        destroyed = false;
      });
      return;
    }
    setState(() {
      destroyed = result.destroyed;
      if (result.succeeded) {
        selectedSerial = result.weapon!.serial;
        message = '강화 성공 · 무기 Lv.${result.weapon!.weaponLevel}';
      } else {
        // Never select and expose another weapon to a rapid second tap.
        selectedSerial = null;
        message = '${gear.name} 소멸 · 다른 무기를 선택하세요';
      }
    });
    widget.onCheckpoint?.call();
  }

  @override
  Widget build(BuildContext context) {
    final items = s.progress.inventory
        .where(
          (gear) =>
              gear.base.slot == GearSlot.weapon &&
              gear.base.usable(s.progress.heroClass),
        )
        .toList();
    final gear = selected;
    final quote = gear == null ? null : s.smithQuote(gear);
    final short = MediaQuery.sizeOf(context).height < 500;
    final affordable = quote != null && s.progress.gold >= quote.price;
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
                    GamePanelHeader(
                      title: '대장간',
                      dense: short,
                      subtitle: short ? null : '무기 강화 · 제한 없는 도전',
                      onClose: widget.onClose,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.monetization_on_rounded,
                            size: 16,
                            color: gold,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${s.progress.gold}',
                            style: const TextStyle(
                              color: gold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: short ? 84 : 92,
                      child: items.isEmpty
                          ? const Center(
                              child: Text(
                                '강화할 무기가 없습니다',
                                style: TextStyle(color: _muted),
                              ),
                            )
                          : Scrollbar(
                              controller: weaponsScroll,
                              thumbVisibility: true,
                              thickness: 3,
                              child: ListView.separated(
                                controller: weaponsScroll,
                                scrollDirection: Axis.horizontal,
                                physics: const ClampingScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  4,
                                  12,
                                  8,
                                ),
                                itemCount: items.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) =>
                                    _weapon(items[index], short),
                              ),
                            ),
                    ),
                    Expanded(
                      child: Scrollbar(
                        controller: detailScroll,
                        thumbVisibility: true,
                        thickness: 3,
                        child: SingleChildScrollView(
                          controller: detailScroll,
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!short) _forgeBanner(),
                              if (message.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: destroyed
                                        ? const Color(0xff3c2524)
                                        : const Color(0xff173f35),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      message,
                                      style: TextStyle(
                                        color: destroyed
                                            ? const Color(0xffffb1a0)
                                            : _mint,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              if (gear == null)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Text(
                                    '위에서 강화할 무기를 선택하세요.\n강화한 무기는 같은 자리에서 계속 강화할 수 있습니다.',
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                  ),
                                )
                              else ...[
                                Text(
                                  gear.name,
                                  style: TextStyle(
                                    color: Color(gear.rarity.color),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (gear.locked)
                                  const Text(
                                    '잠금 무기 · 가방에서 잠금을 해제하세요',
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: 14,
                                    ),
                                  )
                                else if (quote == null)
                                  const Text(
                                    '대장장이 가까이에서 무기를 강화할 수 있습니다',
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: 14,
                                    ),
                                  )
                                else ...[
                                  _comparison(
                                    '무기 레벨',
                                    '${gear.weaponLevel}',
                                    '${gear.weaponLevel! + 1}',
                                  ),
                                  _comparison(
                                    '공격력',
                                    gear.attack.toStringAsFixed(1),
                                    quote.nextAttack.toStringAsFixed(1),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 6,
                                    children: [
                                      _tag('내 레벨 ${s.progress.level}', _muted),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    '무기 레벨이 내 레벨보다 높을수록 성공 확률이 낮아집니다.',
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                                if (gear.gifts.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  for (final ability in gear.gifts)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 5),
                                      child: Text(
                                        '${ability.title} · ${ability.description}',
                                        style: const TextStyle(
                                          color: gold,
                                          fontSize: 12,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 3,
                            children: [
                              if (quote != null)
                                _tag(
                                  '성공 ${(quote.successChance * 100).round()}%',
                                  _mint,
                                  key: const ValueKey('smith-success-chance'),
                                ),
                              if (quote != null)
                                _tag(
                                  '비용 ${quote.price} G',
                                  gold,
                                  key: const ValueKey('smith-enhancement-cost'),
                                ),
                              const Text(
                                '실패 시 선택한 무기 소멸',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xffffb29d),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: GameAction(
                                  quote == null
                                      ? '무기 선택'
                                      : !affordable
                                      ? '골드 부족 · ${quote.price} G'
                                      : '강화 · ${quote.price} G',
                                  primary: true,
                                  minHeight: short ? 44 : 50,
                                  icon: Icons.hardware_rounded,
                                  fontSize: 15,
                                  semanticLabel: quote == null
                                      ? '강화할 무기 선택 필요'
                                      : '${gear!.name} 무기 레벨 ${gear.weaponLevel}에서 ${gear.weaponLevel! + 1} 강화, 비용 ${quote.price} 골드, 성공 ${(quote.successChance * 100).round()}퍼센트, 실패 시 무기 소멸',
                                  onTap: affordable
                                      ? () => enhance(quote)
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GameAction(
                                  '돌아가기',
                                  minHeight: short ? 44 : 50,
                                  fontSize: 14,
                                  onTap: widget.onClose,
                                ),
                              ),
                            ],
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

  Widget _weapon(Gear gear, bool short) {
    final active = gear.serial == selectedSerial;
    final equipped =
        s.progress.equipped[GearSlot.weapon]?.serial == gear.serial;
    return Semantics(
      button: true,
      selected: active,
      label:
          '${gear.name} 무기 레벨 ${gear.weaponLevel}${equipped ? ' 장착 중' : ''}${gear.locked ? ' 잠금' : ''}',
      onTap: () => choose(gear),
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => choose(gear),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 126,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: active ? const Color(0xff25463c) : const Color(0xff0c2828),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? gold : const Color(0xff3f665c),
                width: active ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: short ? 32 : 40,
                  child: CustomPaint(painter: GearGlyph(gear, s.art)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gear.base.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(gear.rarity.color),
                          fontSize: 12,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'Lv.${gear.weaponLevel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: cream,
                          fontSize: 14,
                          height: 1.1,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (equipped || gear.locked)
                        Text(
                          gear.locked ? '잠금' : '장착 중',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _mint,
                            fontSize: 10,
                            height: 1.1,
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
    );
  }

  void choose(Gear gear) => setState(() {
    selectedSerial = gear.serial;
    message = '';
    destroyed = false;
    if (detailScroll.hasClients) detailScroll.jumpTo(0);
  });

  Widget _forgeBanner() => Container(
    constraints: const BoxConstraints(minHeight: 86),
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: const Color(0xff102b29),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 112,
          height: 86,
          child: RawImage(
            image: s.art.images['blacksmith-forge'],
            fit: BoxFit.contain,
          ),
        ),
        const Expanded(
          child: Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              '숲의 화로\n다음 한 번에 운명을 걸어 보세요',
              style: TextStyle(color: cream, fontSize: 14, height: 1.5),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _comparison(String label, String current, String next) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: _muted, fontSize: 14),
          ),
        ),
        Text(current, style: const TextStyle(color: cream, fontSize: 17)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Icon(Icons.arrow_forward_rounded, size: 16, color: gold),
        ),
        Text(
          next,
          style: const TextStyle(
            color: _mint,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );

  Widget _tag(String label, Color color, {Key? key}) => Container(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xff0b2525),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 13)),
  );
}
