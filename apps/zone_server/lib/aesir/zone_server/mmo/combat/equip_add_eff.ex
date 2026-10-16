defmodule Aesir.ZoneServer.Mmo.Combat.EquipAddEff do
  @moduledoc """
  The worn on-hit status bonuses (`bAddEff`, `bAddEff2`, `bAddEffWhenHit`,
  `bAddEffOnSkill`) as `pc_bonus_addeff` and `pc_bonus_addeff_onskill` keep
  them: three ordered lists, the attack list (bAddEff, bAddEff2 and the
  ammunition's chances), the when-hit list and the on-skill list, whose
  entries also name their skill and always target the enemy.

  A bonus registers in the order the worn scripts run. Its flag is completed
  first (both ranges, the enemy as victim and weapon attacks unless named;
  bAddEff2 always names its wearer), and an unset duration becomes the status's
  default: the second duration of its lookup skill at level 7. A bonus of a
  status and flag (on-skill: status and skill) already listed adds its chances
  to that entry and keeps the longer duration; anything else is appended.

  The lists live in the equipment modifiers under `list_key/1`.
  """

  import Bitwise

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.AutoTriggerFlag
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags

  @atf_self AutoTriggerFlag.id(:self)

  # Families that name an on-hit status bonus, by the list they belong to and
  # whether their chance counts only for ranged attacks (the ammunition's).
  @families %{
    add_eff: {:attack, :rate, 0},
    add_eff2: {:attack, :rate, @atf_self},
    arrow_add_eff: {:attack, :arrow_rate, 0},
    arrow_add_eff2: {:attack, :arrow_rate, @atf_self},
    add_eff_when_hit: {:when_hit, :rate, 0}
  }

  @duration_families %{add_eff_duration: :attack, add_eff_when_hit_duration: :when_hit}

  # skill_get_time2(status_db.getSkill(sc), 7): the Duration2 of each status's
  # DurationLookup skill, for the statuses an `Eff_*` constant names.
  @default_durations %{
    renewal: %{
      sc_stun: 4_500,
      sc_freeze: 27_000,
      sc_stonewait: 17_000,
      sc_sleep: 18_000,
      sc_poison: 18_000,
      sc_curse: 18_000,
      sc_silence: 18_000,
      sc_confusion: 18_000,
      sc_blind: 18_000,
      sc_bleeding: 108_000
    },
    pre_renewal: %{
      sc_stun: 5_000,
      sc_freeze: 12_000,
      sc_stonewait: 20_000,
      sc_sleep: 30_000,
      sc_poison: 60_000,
      sc_curse: 30_000,
      sc_silence: 30_000,
      sc_confusion: 30_000,
      sc_blind: 30_000,
      sc_bleeding: 120_000
    }
  }

  @typedoc "Which list an entry belongs to."
  @type list_name :: :attack | :when_hit | :on_skill

  @typedoc "One listed on-hit status bonus."
  @type entry :: %{
          optional(:skill_id) => pos_integer(),
          sc: atom(),
          flag: BattleFlags.flag(),
          rate: integer(),
          arrow_rate: integer(),
          duration: non_neg_integer()
        }

  @typedoc """
  One bonus as a script evaluates it, before registration: its list, status,
  completed flag, chances and the duration it names (0 when none).
  """
  @type bonus :: %{
          optional(:skill_id) => pos_integer(),
          list: list_name(),
          sc: atom(),
          flag: BattleFlags.flag(),
          rate: integer(),
          arrow_rate: integer(),
          duration: integer()
        }

  @doc "The equipment-modifier key holding a list."
  @spec list_key(list_name()) :: {:add_eff_list, list_name()}
  def list_key(list), do: {:add_eff_list, list}

  @doc "The entries of one list in `modifiers`, in registration order."
  @spec entries(map(), list_name()) :: [entry()]
  def entries(modifiers, list), do: Map.get(modifiers, list_key(list), [])

  @doc """
  The bonus a script's `bonus` destination and value name, or nil for any other
  destination.
  """
  @spec bonus(term(), integer()) :: bonus() | nil
  def bonus({family, param}, value) when is_map_key(@families, family) and is_integer(value) do
    {list, rate_key, implied} = Map.fetch!(@families, family)

    with {sc, flag} <- status_and_flag(param, implied) do
      %{list: list, sc: sc, flag: flag, rate: 0, arrow_rate: 0, duration: 0}
      |> Map.put(rate_key, value)
    end
  end

  def bonus({:add_eff_on_skill, skill_id, sc}, value)
      when is_integer(skill_id) and is_atom(sc) and is_integer(value) do
    %{
      list: :on_skill,
      sc: sc,
      skill_id: skill_id,
      flag: BattleFlags.fill_trigger(0),
      rate: value,
      arrow_rate: 0,
      duration: 0
    }
  end

  def bonus(_dest, _value), do: nil

  @doc """
  Whether a destination is the duration a `bonus4` form names for the bonus
  just before it, and which list that bonus belongs to.
  """
  @spec duration_list(term()) :: {:ok, list_name()} | :error
  def duration_list({family, _param}) when is_map_key(@duration_families, family),
    do: {:ok, Map.fetch!(@duration_families, family)}

  def duration_list(_dest), do: :error

  @doc "Registers bonuses, in order, into the lists in `modifiers`."
  @spec register(map(), [bonus()]) :: map()
  def register(modifiers, bonuses), do: Enum.reduce(bonuses, modifiers, &register_one/2)

  @doc "The default duration of `sc` for an on-hit status bonus naming none (0 when unknown)."
  @spec default_duration(atom()) :: non_neg_integer()
  def default_duration(sc),
    do: @default_durations |> Map.fetch!(GameMode.mode()) |> Map.get(sc, 0)

  defp register_one(%{list: list} = bonus, modifiers) do
    duration = if bonus.duration > 0, do: bonus.duration, else: default_duration(bonus.sc)
    entry = %{bonus | duration: duration} |> Map.delete(:list)
    Map.update(modifiers, list_key(list), [entry], &merge(&1, entry))
  end

  defp merge(entries, entry) do
    case Enum.find_index(entries, &(identity(&1) == identity(entry))) do
      nil ->
        entries ++ [entry]

      index ->
        List.update_at(entries, index, fn held ->
          %{
            held
            | rate: held.rate + entry.rate,
              arrow_rate: held.arrow_rate + entry.arrow_rate,
              duration: max(held.duration, entry.duration)
          }
        end)
    end
  end

  defp identity(%{skill_id: skill_id} = entry), do: {entry.sc, skill_id}
  defp identity(entry), do: {entry.sc, entry.flag}

  defp status_and_flag({sc, flag}, implied) when is_atom(sc) and is_integer(flag),
    do: {sc, BattleFlags.fill_trigger(flag ||| implied)}

  defp status_and_flag(sc, implied) when is_atom(sc), do: {sc, BattleFlags.fill_trigger(implied)}
  defp status_and_flag(_param, _implied), do: nil
end
