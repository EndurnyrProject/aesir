defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Autoguard do
  @moduledoc """
  Guard (SC_AUTOGUARD).

  The persistent shield-block stance toggled by CR_AUTOGUARD, carrying the skill
  level in `val1`. While active, every weapon hit that connects on the holder
  for damage rolls against a per-level block chance in `absorb_damage/4`, the
  last blocker of the damage stage after Kyrie Eleison, Safety Wall, Pneuma and
  Basilica: the hit roll, the damage calculation and the earlier blockers all
  run first, so a missed or dodged swing never rolls a block. On a successful
  roll the hit deals nothing, its additional effects are skipped, a seated
  holder stands up, and a guard sprite plays for nearby viewers on the holder,
  or on the holder's Crusader when a valid Devotion link covers the holder.
  Whoever shows the guard gets a walk delay of 300 ms through level 5, 200 ms
  through level 9 and 100 ms at level 10.

  Unlike Auto Counter this is not a single-use stance: a successful block leaves
  the status in place, so it keeps guarding every subsequent weapon hit until the
  skill is re-cast to toggle it off. Only weapon-class hits reach the roll -
  basic attacks and weapon skills - so magic and misc damage is never blocked,
  nor is a skill whose definition sets `ignore_auto_guard`.

  The block chance is fixed when the status starts on its own (5 to 30 percent
  by level, kept in `state.block_chance`); a Devotion copy carries its
  Crusader's chance, or none when inherited at link time. It lasts 300 seconds
  unless re-cast off, is kept across a logout (a restored status is the
  holder's own, as a logout ends every Devotion link and the copies with it,
  so its chance is fixed again from `val1`), and starts and ends its devotees'
  copies (`DevotionMirror`). The shield
  requirement is checked by the skill at cast time, and the
  `:remove_on_unequip_shield` flag drops the stance if the shield is later
  unequipped or displaced without another shield taking its place.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_autoguard,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:remove_on_hermode],
    duration: 300_000,
    properties: [:buff],
    flags: [:remove_on_unequip_shield],
    icon: :autoguard

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.StatusEffect.DevotionMirror
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Devotion
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Shrink
  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.SpecialEffect

  @impl true
  def on_apply(target, instance, context) do
    state =
      if DevotionMirror.copy?(instance),
        do: instance.state,
        else: Map.put(instance.state, :block_chance, block_chance(instance.val1))

    DevotionMirror.started(target, instance, state, context.duration)
    {:ok, %{instance | state: state}}
  end

  @impl true
  def on_expire(target, instance, _context), do: DevotionMirror.ended(target, instance)

  @impl true
  @spec absorb_damage({Unit.unit_type(), integer()}, StatusEntry.t(), map(), map()) ::
          {:ok, non_neg_integer(), StatusEntry.t()}
  def absorb_damage(target, %StatusEntry{} = entry, %{dmg_type: :physical} = hit_info, _context) do
    if guards?(entry, hit_info) do
      blocked(target, entry, hit_info)
      {:ok, 0, entry}
    else
      {:ok, hit_info.damage, entry}
    end
  end

  def absorb_damage(_target, entry, %{damage: damage}, _context), do: {:ok, damage, entry}

  defp guards?(entry, hit_info) do
    not ignores_auto_guard?(Map.get(hit_info, :skill_id)) and
      :rand.uniform(100) <= Map.get(entry.state, :block_chance, 0)
  end

  # A hit covered by a valid Devotion link shows the guard on the Crusader and
  # never triggers Shrink; any other hit shows it on the holder.
  defp blocked({:player, holder_id} = holder, entry, hit_info) do
    Helpers.force_stand(holder)

    case Devotion.redirect_target(holder_id) do
      {:ok, crusader_id} -> guard_shown({:player, crusader_id}, entry)
      _not_devoted -> blocked_by_holder(holder, entry, hit_info)
    end
  end

  defp blocked(holder, entry, hit_info), do: blocked_by_holder(holder, entry, hit_info)

  defp blocked_by_holder(holder, %StatusEntry{val1: level} = entry, hit_info) do
    guard_shown(holder, entry)
    maybe_shrink_stun(holder, hit_info, level)
  end

  defp guard_shown(unit, %StatusEntry{val1: level}) do
    SpecialEffect.play(unit, :guard, :area)
    Helpers.walk_delay(unit, walk_delay(level))
  end

  defp walk_delay(level) when level <= 5, do: 300
  defp walk_delay(level) when level <= 9, do: 200
  defp walk_delay(_level), do: 100

  defp ignores_auto_guard?(skill_id) when is_integer(skill_id) do
    match?({:ok, %{ignore_auto_guard: true}}, Catalog.by_id(skill_id))
  end

  defp ignores_auto_guard?(_skill_id), do: false

  @spec maybe_shrink_stun({Unit.unit_type(), integer()}, map(), integer()) :: :ok
  defp maybe_shrink_stun(guarder, %{attacker: {_type, _id} = attacker}, level),
    do: Shrink.maybe_stun_attacker(guarder, attacker, level)

  defp maybe_shrink_stun(_guarder, _hit_info, _level), do: :ok

  @doc """
  The block chance percent of a status started at `level`: 5, 5, 4, 4, 3, 3, 2,
  2, 1, 1 added per level, then 0 twice, then 1 per level beyond.
  """
  @spec block_chance(integer()) :: non_neg_integer()
  def block_chance(level) do
    Enum.reduce(0..(level - 1)//1, 0, fn step, chance ->
      added = 5 - div(step, 2)
      chance + if(added < 0, do: 1, else: added)
    end)
  end
end
