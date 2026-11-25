defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.SwanInn do
  @moduledoc """
  A sleeping guest wakes at the Swan Inn.

  ## Behavior

  - Advances the search for Mikhail after the guest rests.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mosk_in",
        x: 215,
        y: 181,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#swan_inn",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx), do: ctx

  @impl true
  def on_event("OnTouch", ctx) do
    if get_char_var(ctx, :mos_swan, 0) == 4 do
      wake_up(ctx)
    else
      ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp wake_up(ctx) do
    ctx =
      ctx
      |> mes("..................")
      |> mes("..................")
      |> next()
      |> mes("..................")
      |> mes("..................")
      |> mes("..................")
      |> next()
      |> mes("..................")
      |> mes("..................")
      |> mes("..................")
      |> mes("..................")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Oh, I got a good night's sleep. How long did I sleep?")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Although I was forced to stay here, it's true that it's got great facilities.")
      |> mes("I feel refreshed.")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Ok, I guess I will go to the landlord to get some info.")
    |> set_char_var(:mos_swan, 5)
    |> close()
  end
end
