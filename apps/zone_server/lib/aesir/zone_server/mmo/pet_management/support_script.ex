defmodule Aesir.ZoneServer.Mmo.PetManagement.SupportScript do
  @moduledoc """
  Transpiles a `pet_db` `SupportScript` into ordered declarative ops, one per
  pet support buildin (`petskillbonus` and its siblings).

  Arguments are resolved the way each buildin stores them: `petloot` clamps its
  size to 1..30, and `petskillattack` caps its level at the skill's max level.
  Any other statement, command or a non-literal argument raises, so the import
  fails loudly.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.BonusKeys
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Resolver
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Npc.Transpiler.Parser

  @max_loot 30

  @typedoc "One pet support behaviour, in script order."
  @type support_op ::
          {:petskillbonus, atom(), integer(), integer(), integer()}
          | {:petrecovery, atom(), integer()}
          | {:petloot, 1..30}
          | {:petskillattack, pos_integer(), non_neg_integer(), integer(), integer()}
          | {:petskillattack2, pos_integer(), integer(), integer(), integer(), integer()}
          | {:petskillsupport, pos_integer(), integer(), integer(), integer(), integer()}

  @doc "Transpiles a support script source into its ordered ops; raises on anything else."
  @spec transpile(String.t()) :: [support_op()]
  def transpile(source) when is_binary(source) do
    case Parser.parse_body(source) do
      {:ok, statements} -> Enum.map(statements, &op!/1)
      {:error, reason} -> raise ArgumentError, "unparsable SupportScript: #{inspect(reason)}"
    end
  end

  defp op!({:cmd, "petskillbonus", [bonus, value, duration, delay]}) do
    {:petskillbonus, bonus_key!(bonus), uint16!(value), uint16!(duration), uint16!(delay)}
  end

  defp op!({:cmd, "petrecovery", [status, delay]}),
    do: {:petrecovery, status!(status), uint16!(delay)}

  defp op!({:cmd, "petloot", [max]}),
    do: {:petloot, max |> int!() |> max(1) |> min(@max_loot)}

  defp op!({:cmd, "petskillattack", [skill, level, rate, bonus_rate]}) do
    {skill_id, max_level} = skill!(skill)

    {:petskillattack, skill_id, Integer.mod(min(int!(level), max_level), 65_536), uint16!(rate),
     uint16!(bonus_rate)}
  end

  defp op!({:cmd, "petskillattack2", [skill, damage, div, rate, bonus_rate]}) do
    {skill_id, _max_level} = skill!(skill)

    {:petskillattack2, skill_id, uint16!(damage), uint16!(div), uint16!(rate),
     uint16!(bonus_rate)}
  end

  defp op!({:cmd, "petskillsupport", [skill, level, delay, hp, sp]}) do
    {skill_id, _max_level} = skill!(skill)
    {:petskillsupport, skill_id, uint16!(level), uint16!(delay), uint16!(hp), uint16!(sp)}
  end

  defp op!(statement),
    do: raise(ArgumentError, "unsupported SupportScript statement: #{inspect(statement)}")

  defp uint16!(arg), do: Integer.mod(int!(arg), 65_536)

  defp int!({:int, value}), do: value
  defp int!({:neg, {:int, value}}), do: -value
  defp int!(arg), do: raise(ArgumentError, "expected an integer literal, got #{inspect(arg)}")

  defp bonus_key!({:name, name} = arg) do
    case BonusKeys.destination(name) do
      {:ok, key} -> key
      :error -> raise ArgumentError, "unknown bonus #{inspect(arg)}"
    end
  end

  defp bonus_key!(arg), do: raise(ArgumentError, "expected a bonus constant, got #{inspect(arg)}")

  defp status!({:name, name} = arg) do
    case Resolver.resolve_status(name) do
      {:ok, status} -> status
      {:error, _} -> raise ArgumentError, "unknown status #{inspect(arg)}"
    end
  end

  defp status!(arg), do: raise(ArgumentError, "expected a status constant, got #{inspect(arg)}")

  defp skill!({kind, ref} = arg) when kind in [:int, :str, :name] do
    with {:ok, skill_id} <- Resolver.resolve_skill(ref),
         {:ok, %{max_level: max_level}} <- Catalog.by_id(skill_id) do
      {skill_id, max_level}
    else
      _ -> raise ArgumentError, "unknown skill #{inspect(arg)}"
    end
  end

  defp skill!(arg), do: raise(ArgumentError, "expected a skill, got #{inspect(arg)}")
end
