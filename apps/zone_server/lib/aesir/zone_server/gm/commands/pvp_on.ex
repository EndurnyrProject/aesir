defmodule Aesir.ZoneServer.Gm.Commands.PvpOn do
  @moduledoc """
  `@pvpon [noparty] [noguild]` - enables PvP on the calling GM's current map.

  With no args only the `pvp` map flag is set; naming `noparty` and/or `noguild`
  additionally sets the corresponding modifier. Omitted modifiers are not
  implicitly cleared - `@pvpoff` owns that. All args are validated before any
  flag is mutated. Level 99 GMs only.
  """
  @behaviour Aesir.ZoneServer.Gm.Command

  alias Aesir.ZoneServer.Map.MapFlags

  @usage "Usage: @pvpon [noparty] [noguild]"

  @impl true
  def name, do: "pvpon"

  @impl true
  def required_level, do: 99

  @impl true
  def execute(args, ctx) do
    case parse(args) do
      {:ok, modifier_flags} ->
        map = ctx.game_state.map_name

        MapFlags.set_runtime(map, :pvp, true)

        Enum.each(modifier_flags, fn flag ->
          MapFlags.set_runtime(map, flag, true)
        end)

        {:ok, "PvP enabled."}

      {:error, message} ->
        {:error, message}
    end
  end

  defp parse(args) do
    if Enum.all?(args, &(&1 in ["noparty", "noguild"])) do
      {:ok, Enum.map(args, &modifier_flag/1)}
    else
      {:error, @usage}
    end
  end

  defp modifier_flag("noparty"), do: :pvp_noparty
  defp modifier_flag("noguild"), do: :pvp_noguild
end
