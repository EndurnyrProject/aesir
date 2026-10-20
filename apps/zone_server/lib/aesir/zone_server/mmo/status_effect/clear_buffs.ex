defmodule Aesir.ZoneServer.Mmo.StatusEffect.ClearBuffs do
  @moduledoc """
  Clears a unit's buffs and debuffs by family, as Gospel, Hermode and Tarot's
  High Priestess do.

  A unit holding no status is left untouched. Otherwise every held status
  flagged `no_clear_buff` is skipped whatever the call asks for; any other
  status ends when one of the requested families matches its
  `clear_buff_flags`:

  * `:chem_protect` - statuses flagged `:remove_chemical_protect`
  * `:refresh` - statuses flagged `:remove_on_refresh`
  * `:debuffs` - statuses flagged `:debuff`
  * `:buffs` - every status not flagged `:debuff`, ailments included
  * `:hermode` - statuses flagged `:remove_on_hermode`

  A held Berserk loses its expiry HP penalty even when the call does not end
  it. After the clearing, the classic Storm Gust hit counter resets.

  Statuses marked `engine_only` do not make a unit count as holding a status.
  Removal runs through `Interpreter.remove_statuses/4`, so `on_expire`, icons and
  calc-flag recomputation fire as on natural expiry. Clearing never checks magic
  immunity.
  """

  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @typedoc "One family of statuses a clearing ends."
  @type family :: :buffs | :debuffs | :chem_protect | :refresh | :hermode

  @family_flags %{
    chem_protect: :remove_chemical_protect,
    refresh: :remove_on_refresh,
    debuffs: :debuff,
    hermode: :remove_on_hermode
  }

  @doc """
  Ends the target's statuses of the requested families.

  `except:` names status ids the clearing never touches, for a caller that holds
  a status of one of the families and must survive its own wipe (Gospel's
  chant).
  """
  @spec clear(Definition.target(), [family()], keyword()) :: :ok
  def clear(target, families, opts \\ [])

  def clear({unit_type, unit_id}, families, opts) do
    except = Keyword.get(opts, :except, [])

    held =
      unit_type
      |> StatusStorage.get_unit_statuses(unit_id)
      |> Enum.map(&{&1.type, Registry.get_definition(&1.type)})

    if Enum.any?(held, fn {_id, definition} -> not definition.engine_only end) do
      clearable =
        Enum.reject(held, fn {id, definition} ->
          definition.no_clear_buff or id in except
        end)

      if List.keymember?(clearable, :sc_berserk, 0), do: disarm_berserk(unit_type, unit_id)

      ids = for {id, definition} <- clearable, ends?(definition, families), do: id
      Interpreter.remove_statuses(unit_type, unit_id, ids, owner_refresh: :notify)
      StatusStorage.reset_storm_gust_counter(unit_type, unit_id)
    end

    :ok
  end

  defp ends?(%{clear_buff_flags: flags}, families) do
    Enum.any?(families, fn
      :buffs -> :debuff not in flags
      family -> Map.fetch!(@family_flags, family) in flags
    end)
  end

  defp disarm_berserk(unit_type, unit_id) do
    StatusStorage.update_status(
      unit_type,
      unit_id,
      :sc_berserk,
      &Helpers.put_state(&1, :penalty_armed, false)
    )
  end
end
