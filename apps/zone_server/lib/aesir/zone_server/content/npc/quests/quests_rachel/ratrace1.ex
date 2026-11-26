defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Ratrace1 do
  @moduledoc """
  A trace of Bruspetti’s perfume in Lighthalzen.

  ## Behavior

  - Reveals a clue and advances the investigation when the player enters the area.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in02",
        x: 213,
        y: 207,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#ratrace1",
        trigger: {4, 4}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnTouch_", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :rach_vice, 0) == 5 do
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("This...")
      |> mes("This smell...")
      |> mes("It smells so nice!")
      |> mes("Like rose petals riding")
      |> mes("on a gentle breeze...")
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Wait, could this be")
      |> mes("the scent that Bruspetti's")
      |> mes("father mentioned earlier?")
      |> set_char_var(:rach_vice, 6)
      |> changequest(8109, 8110)
      |> close()
    else
      ctx
    end
  end
end
