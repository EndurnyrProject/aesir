defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Switch do
  @moduledoc """
  Opens the passage to the witch encounter.

  ## Behavior

  - Updates quest variables and warps eligible players to the encounter.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "nif_in",
        x: 140,
        y: 177,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#Switch"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])

    cond do
      count_item(ctx, 7313) == 1 ->
        warp(ctx, "que_sign01", 115, 135)

      get_char_var(ctx, :sign_q, 0) > 89 ->
        ctx =
          if get_char_var(ctx, :sign_q, 0) == 126 do
            set_char_var(ctx, :sign_q, 198)
          else
            ctx
          end

        warp(ctx, "que_sign01", 115, 135)

      true ->
        ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
