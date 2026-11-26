defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.WallCloset do
  @moduledoc """
  A closet holds a pyrometer for the investigation.

  ## Behavior

  - Gives the pyrometer when needed, subject to inventory capacity.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ve_in",
        x: 277,
        y: 229,
        dir: 3,
        sprite: 111,
        name: "Wall Closet",
        scope: :shared,
        unique_name: "Wall Closet#vol"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      max_weight(ctx) - weight(ctx) < 2000 or checkweight(ctx, [{1201, 1}]) == 0 ->
        ctx
        |> mes("^3355FFWait a second!")
        |> mes("Right now, you're carrying")
        |> mes("too many things with you.")
        |> mes("Please come back after")
        |> mes("using the Kafra Service")
        |> mes("to store some of your items.^000000")
        |> close()

      get_char_var(ctx, :aru_vol, 0) == 8 and count_item(ctx, 7704) == 0 ->
        ctx
        |> mes("^3355FFYou found the")
        |> mes("pyrometer inside")
        |> mes("the closet.^000000")
        |> give_item(7704, 1)
        |> close()

      true ->
        ctx |> mes("^3355FFThere's so much junk") |> mes("crammed in here!^000000") |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
