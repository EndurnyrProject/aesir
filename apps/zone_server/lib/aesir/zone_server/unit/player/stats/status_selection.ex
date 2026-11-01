defmodule Aesir.ZoneServer.Unit.Player.Stats.StatusSelection do
  @moduledoc "Selects player calculation channels and their mode-specific primary dependencies."

  alias Aesir.ZoneServer.Unit.Player.Stats

  @primaries %{
    "Str" => :str,
    "Agi" => :agi,
    "Vit" => :vit,
    "Int" => :int,
    "Dex" => :dex,
    "Luk" => :luk,
    "Pow" => :pow,
    "Sta" => :sta,
    "Wis" => :wis,
    "Spl" => :spl,
    "Con" => :con,
    "Crt" => :crt
  }

  @dependencies %{
    "Str" => ~w(Batk),
    "Agi" => ~w(Flee Aspd Dspd),
    "Vit" => ~w(Def2 Mdef2 MaxHp),
    "Int" => ~w(Matk Mdef2 MaxSp),
    "Dex" => ~w(Batk Hit Aspd),
    "Luk" => ~w(Batk Cri Flee2)
  }
  @renewal_dependencies %{
    "Agi" => ~w(Def2),
    "Dex" => ~w(Matk Mdef2),
    "Luk" => ~w(Matk Hit Flee),
    "Pow" => ~w(Batk Patk),
    "Sta" => ~w(Res),
    "Wis" => ~w(Mres),
    "Spl" => ~w(Matk Smatk),
    "Con" => ~w(Hit Flee Patk Smatk),
    "Crt" => ~w(Hplus Crate)
  }

  @combat %{
    "Batk" => [:atk, :physical_attack],
    "Watk" => [:atk, :physical_attack],
    "Matk" => [:matk, :matk_min, :matk_max, :heal_matk_min, :heal_matk_max],
    "Hit" => [:hit],
    "Flee" => [:flee],
    "Def" => [:def],
    "Def2" => [:soft_def],
    "Mdef" => [:mdef],
    "Mdef2" => [:soft_mdef],
    "Cri" => [:critical, :critical_rate],
    "Flee2" => [:perfect_dodge],
    "Patk" => [:patk],
    "Smatk" => [:smatk],
    "Res" => [:res],
    "Mres" => [:mres],
    "Hplus" => [:hplus],
    "Crate" => [:crate]
  }
  @derived %{
    "MaxHp" => [:max_hp],
    "MaxSp" => [:max_sp],
    "MaxAp" => [:max_ap],
    "Aspd" => [:aspd]
  }

  @typedoc "Published fields selected by a status calculation, including dependency closure."
  @type selection() :: %{
          full?: boolean(),
          walk_speed?: boolean(),
          primary: MapSet.t(atom()),
          combat: MapSet.t(atom()),
          derived: MapSet.t(atom())
        }

  @doc "Expands calculation flags without treating a partial selection as a full recalculation."
  @spec affected_fields([String.t()], :renewal | :pre_renewal) :: selection()
  def affected_fields(flags, mode) do
    selected =
      Enum.reduce(flags, MapSet.new(flags), fn flag, selected ->
        dependencies =
          Map.get(@dependencies, flag, []) ++ renewal_dependencies(flag, mode)

        Enum.reduce(dependencies, selected, &MapSet.put(&2, &1))
      end)

    %{
      full?: "All" in flags or "Base" in flags,
      walk_speed?: MapSet.member?(selected, "Speed"),
      primary: select_primary(selected),
      combat: select_fields(selected, @combat),
      derived: select_fields(selected, @derived)
    }
  end

  @doc "Publishes selected calculated fields while preserving every unrelated cached channel."
  @spec project(Stats.t(), Stats.t(), selection()) :: Stats.t()
  def project(_previous, calculated, %{full?: true}), do: calculated

  def project(previous, calculated, selection) do
    modifiers = %{
      previous.modifiers
      | status_effects:
          project_primary_modifiers(
            previous.modifiers.status_effects,
            calculated.modifiers.status_effects,
            selection.primary
          ),
        statuses_active?: calculated.modifiers.statuses_active?
    }

    %{
      previous
      | modifiers: modifiers,
        combat_stats:
          copy_fields(previous.combat_stats, calculated.combat_stats, selection.combat),
        derived_stats:
          copy_fields(previous.derived_stats, calculated.derived_stats, selection.derived),
        current_state:
          copy_fields(
            previous.current_state,
            calculated.current_state,
            resource_fields(selection)
          )
    }
  end

  defp project_primary_modifiers(previous, calculated, primary) do
    Enum.reduce(@primaries, calculated, fn {_flag, stat}, modifiers ->
      cond do
        MapSet.member?(primary, stat) -> modifiers
        Map.has_key?(previous, stat) -> Map.put(modifiers, stat, Map.fetch!(previous, stat))
        true -> Map.delete(modifiers, stat)
      end
    end)
  end

  defp copy_fields(previous, calculated, fields) do
    case Enum.to_list(fields) do
      [] -> previous
      keys -> Map.merge(previous, Map.take(calculated, keys))
    end
  end

  defp resource_fields(selection) do
    for {maximum, current} <- [max_hp: :hp, max_sp: :sp, max_ap: :ap],
        MapSet.member?(selection.derived, maximum),
        do: current
  end

  defp renewal_dependencies(flag, :renewal), do: Map.get(@renewal_dependencies, flag, [])
  defp renewal_dependencies(_flag, :pre_renewal), do: []

  defp select_primary(selected) do
    for {flag, field} <- @primaries, MapSet.member?(selected, flag), into: MapSet.new(), do: field
  end

  defp select_fields(selected, fields) do
    selected
    |> Enum.flat_map(&Map.get(fields, &1, []))
    |> MapSet.new()
  end
end
