defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Alex15108 do
  @moduledoc """
  An entrance reveals Alex and Julian arguing about the excavation.

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
        map: "hu_in01",
        x: 15,
        y: 108,
        dir: 0,
        sprite: 45,
        name: "alex",
        scope: :shared,
        unique_name: "alex#warp",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnTouch_", ctx), do: on_talk(ctx)

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :hg_odin, 0) do
      17 -> overhear(ctx)
      18 -> ctx |> mes("......") |> mes(".........") |> close()
      _ -> warp(ctx, "hu_in01", 15, 155)
    end
  end

  defp overhear(ctx) do
    ctx =
      ctx
      |> mes("[Alex]")
      |> mes("Haven't you found it yet?")
      |> mes("You said that it'd be here!")
      |> mes("You told me so many people")
      |> mes("are drawn to his place since")
      |> mes("Ymir's Heart might really")
      |> mes("be buried in this area!")
      |> next()
      |> mes("[Julian]")
      |> mes("I'm pretty sure it's")
      |> mes("around here somewhere,")
      |> mes("but I need more time to dig!")
      |> next()
      |> mes("[Alex]")
      |> mes("I understand why you wanted")
      |> mes("to follow me here, but there's")
      |> mes("no way to confirm its existence")
      |> mes("in this area without digging")
      |> mes("it up. Plus, I'm still worried")
      |> mes("about the ''Shinokas'' issue...")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("...Shinokas?")
    |> next()
    |> mes("[Alex]")
    |> mes("We couldn't find")
    |> mes("Ymir's Heart inside")
    |> mes("the village, either...")
    |> mes("Why don't you just--")
    |> next()
    |> mes("[Julian]")
    |> mes("Yeah, you think you can do")
    |> mes("everything yourself since")
    |> mes("you're so much better than")
    |> mes("me, huh?! I'm the black sheep")
    |> mes("of the family, and father loves")
    |> mes("you more than me, right?!")
    |> next()
    |> mes("[Alex]")
    |> mes("You already know that.")
    |> next()
    |> mes("[Julian]")
    |> mes("Wha--?!")
    |> mes("Why... I...!")
    |> next()
    |> mes("[Alex]")
    |> mes("Geez, you're impatient.")
    |> mes("Listen, your ambitions")
    |> mes("can ruin everything. You're")
    |> mes("not planning on defying me,")
    |> mes("are you? Because if you are...")
    |> next()
    |> mes("[Julian]")
    |> mes("You can never understand")
    |> mes("why I want to find Ymir's")
    |> mes("Heart! I'm not going to give")
    |> mes("up looking for it, so just")
    |> mes("leave me alone!")
    |> next()
    |> mes("[Alex]")
    |> mes("I know you better than")
    |> mes("yourself, and I can do")
    |> mes("everything better than you")
    |> mes("can. Forget Ymir's Heart for")
    |> mes("now. Giantes is our highest,")
    |> mes("most important priority!")
    |> next()
    |> mes("[Julian]")
    |> mes("You always...!")
    |> mes("...............................")
    |> mes("Wait... You hear that?")
    |> next()
    |> set_char_var(:hg_odin, 18)
    |> mes("[Alex]")
    |> mes("We'll continue this")
    |> mes("conversation later.")
    |> close()
  end
end
