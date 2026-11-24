defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Hiddenhugel do
  @moduledoc """
  An overheard conversation warns players that Thierry is in danger.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "odin_tem01",
        x: 111,
        y: 144,
        dir: 0,
        sprite: 139,
        name: "HiddenHugel",
        scope: :shared,
        trigger: {2, 2}
      }
    ]

  @impl true
  def on_event("OnTouch", ctx), do: on_talk(ctx)

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :hg_ma1, 0) == 9 do
      ctx
      |> mes("^3355FFYou hear the voice of")
      |> mes("the suspicious man that")
      |> mes("was speaking to Thierry")
      |> mes("a little while ago. You")
      |> mes("carefully listen to what")
      |> mes("he is saying...^000000")
      |> next()
      |> mes("[Suspicious Man]")
      |> mes("Thierry seems to have")
      |> mes("caught on to what we're")
      |> mes("really up to. I think that's why he's slowing down on his")
      |> mes("research. We better get rid")
      |> mes("of him before it's too late.")
      |> next()
      |> mes("[Very Suspicious Man]")
      |> mes("Sure. Just let me")
      |> mes("know when you")
      |> mes("want him dead.")
      |> mes("Then I'll kill him.")
      |> mes("No problem.")
      |> next()
      |> mes("^3355FFThis isn't good!")
      |> mes("Thierry's in danger, so")
      |> mes("you better go tell him")
      |> mes("about this right now!^000000")
      |> close()
      |> set_char_var(:hg_ma1, 10)
      |> changequest(8049, 8050)
    else
      ctx
    end
  end
end
