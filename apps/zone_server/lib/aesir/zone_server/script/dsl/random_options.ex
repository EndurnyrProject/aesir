defmodule Aesir.ZoneServer.Script.Dsl.RandomOptions do
  @moduledoc """
  Random option buildins for the script DSL: reading and setting the options
  of a worn item, rolling a random option group into script arrays, and the
  option read that only means something inside an option's own script.

  An option attribute type is 0 for the id, 1 for the value and 2 for the
  parameter. Imported into scripts via the `Aesir.ZoneServer.Script.Dsl`
  facade.
  """

  import Bitwise
  import Aesir.ZoneServer.Script.Dsl.Internal, only: [no_player!: 2]

  alias Aesir.Commons.Models.ItemOptions
  alias Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions
  alias Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions.Roller
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl.Internal
  alias Aesir.ZoneServer.Script.Dsl.Variables
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @empty %{id: 0, value: 0, param: 0}

  @doc """
  Reads the running random option's attribute. A script outside an option's
  own bonus script has no running option, so it reads 0. Ends a detached
  script.
  """
  @spec getrandomoptinfo(Ctx.t(), integer()) :: 0
  def getrandomoptinfo(%Ctx{game_state: nil} = ctx, _type),
    do: no_player!(ctx, "getrandomoptinfo/2")

  def getrandomoptinfo(%Ctx{}, _type), do: 0

  @doc """
  Reads attribute `type` of option slot `index` of the item worn in equip
  `slot`, of the attached player or of the online character `char_id`.
  Reads -1 for an index outside 0..4, an empty slot or an offline character,
  and 0 for an unknown attribute type. Ends a detached script.
  """
  @spec getequiprandomoption(Ctx.t(), integer(), integer(), integer(), integer() | nil) ::
          integer()
  def getequiprandomoption(ctx, slot, index, type, char_id \\ nil)

  def getequiprandomoption(%Ctx{game_state: nil} = ctx, _slot, _index, _type, nil),
    do: no_player!(ctx, "getequiprandomoption/4")

  def getequiprandomoption(%Ctx{game_state: game_state}, slot, index, type, nil),
    do: read_option(game_state, slot, index, type)

  def getequiprandomoption(%Ctx{} = ctx, slot, index, type, char_id) do
    case target_state(ctx, char_id) do
      {:ok, game_state} -> read_option(game_state, slot, index, type)
      :error -> -1
    end
  end

  defp read_option(game_state, slot, index, type) when index in 0..4 do
    case worn_item(game_state, slot) do
      nil -> -1
      item -> item.random_options |> Enum.at(index, @empty) |> attribute(type)
    end
  end

  defp read_option(_game_state, _slot, _index, _type), do: -1

  defp attribute(option, 0), do: option.id
  defp attribute(option, 1), do: option.value
  defp attribute(option, 2), do: option.param
  defp attribute(_option, _type), do: 0

  @doc """
  Sets option slot `index` of the item worn in equip `slot` to option `id`
  with `value` and `param`, for the attached player or the online character
  `char_id`, and returns 1, or 0 when the option is unknown, the index is
  outside 0..4, the slot is empty or the character is offline. The player's
  own session takes the item off, sets the slot and puts it back on. The id
  and value are stored in 16 bits and the parameter in 8. Ends a detached
  script.
  """
  @spec setrandomoption(
          Ctx.t(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer() | nil
        ) :: {Ctx.t(), 0 | 1}
  def setrandomoption(ctx, slot, index, id, value, param, char_id \\ nil)

  def setrandomoption(%Ctx{status: {:error, _}} = ctx, _slot, _index, _id, _value, _param, _char),
    do: {ctx, 0}

  def setrandomoption(%Ctx{session_pid: nil} = ctx, _slot, _index, _id, _value, _param, nil),
    do: {Ctx.halt(ctx, :no_player), 0}

  def setrandomoption(%Ctx{} = ctx, slot, index, id, value, param, char_id) do
    with {:ok, _option} <- RandomOptions.option(band(id, 0xFFFF)),
         true <- index in 0..4,
         location when not is_nil(location) <- Internal.equip_slot_location(slot) do
      option = %{id: signed(id, 16), value: signed(value, 16), param: signed(param, 8)}
      apply_set(ctx, char_id, {:set_random_option, location, index, option})
    else
      _ -> {ctx, 0}
    end
  end

  defp apply_set(%Ctx{char_id: own} = ctx, char_id, op) when char_id in [nil, own] do
    case PlayerSession.script_apply(ctx.session_pid, op) do
      {:ok, game_state} -> {%{ctx | game_state: game_state}, 1}
      {:error, _reason} -> {ctx, 0}
    end
  end

  defp apply_set(ctx, char_id, op) do
    with {:ok, {_module, _game_state, pid}} when is_pid(pid) <-
           UnitRegistry.get_unit(:player, char_id),
         {:ok, _game_state} <- PlayerSession.script_apply(pid, op) do
      {ctx, 1}
    else
      _ -> {ctx, 0}
    end
  end

  @doc """
  Rolls random option group `id` onto an empty item and writes its five
  option slots to the script arrays `.@opt_id`, `.@opt_value` and
  `.@opt_param`; an array's trailing zeros are left unset, as writing 0 to a
  script array element unsets it. An unknown group fails the command and the script goes on.
  """
  @spec randomoptgroup(Ctx.t(), integer()) :: Ctx.t()
  def randomoptgroup(%Ctx{status: {:error, _}} = ctx, _id), do: ctx

  def randomoptgroup(%Ctx{} = ctx, id) do
    case RandomOptions.group(id) do
      {:ok, group} ->
        slots = group |> Roller.roll() |> ItemOptions.pad()

        ctx
        |> Variables.set_local(:opt_id, slots |> Enum.map(& &1.id) |> trim_zeros())
        |> Variables.set_local(:opt_value, slots |> Enum.map(& &1.value) |> trim_zeros())
        |> Variables.set_local(:opt_param, slots |> Enum.map(& &1.param) |> trim_zeros())

      :error ->
        Ctx.fail(ctx, :randomoptgroup, :unknown_random_option_group)
    end
  end

  defp trim_zeros(values),
    do: values |> Enum.reverse() |> Enum.drop_while(&(&1 == 0)) |> Enum.reverse()

  defp worn_item(game_state, slot) do
    with location when not is_nil(location) <- Internal.equip_slot_location(slot),
         {_index, item} <- Internal.find_equipped_entry(game_state.inventory, location) do
      item
    else
      _ -> nil
    end
  end

  defp target_state(%Ctx{char_id: char_id, game_state: game_state}, char_id)
       when not is_nil(game_state),
       do: {:ok, game_state}

  defp target_state(_ctx, char_id) do
    case UnitRegistry.get_unit(:player, char_id) do
      {:ok, {_module, game_state, _pid}} -> {:ok, game_state}
      _ -> :error
    end
  end

  defp signed(value, bits) do
    <<cast::signed-size(^bits)>> = <<value::size(bits)>>
    cast
  end
end
