defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.StrangeMan do
  @moduledoc """
  Torpy's father emerges from his hiding place after receiving food.

  ## Behavior

  - Advances the Hide and Seek Quest and returns to hiding after a conversation or timer.

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
        map: "hugel",
        x: 100,
        y: 174,
        dir: 3,
        sprite: 898,
        name: "Strange Man",
        scope: :shared,
        unique_name: "Strange Man#Hugel"
      }
    ]

  @impl true
  def on_event("OnEnable", ctx) do
    ctx |> enablenpc("Strange Man#Hugel") |> disablenpc("Suspicious Barrel") |> initnpctimer()
  end

  def on_event("OnInit", ctx), do: disablenpc(ctx, "Strange Man#Hugel")

  def on_event("OnTimer60000", ctx) do
    ctx |> stopnpctimer() |> disablenpc("Strange Man#Hugel") |> enablenpc("Suspicious Barrel")
  end

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :hg_ubu01, 0) == 5 do
      ctx =
        ctx
        |> mes("[Strange Man]")
        |> mes("Ahhhh... Thanks for")
        |> mes("the free meal! It was")
        |> mes("so invigorating! Well,")
        |> mes("I better climb back")
        |> mes("inside that barrel. See")
        |> mes("ya round, adventurer~")
        |> next()

      ctx =
        ctx
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("Hold it!")
        |> mes("Why are you hiding")
        |> mes("inside that barrel?!")
        |> next()
        |> mes("[Strange Man]")
        |> mes("Huh? Oh, I'm just")
        |> mes("playing Hide-and-Seek")
        |> mes("with my son, that's all.")
        |> next()

      ctx =
        ctx
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("But you haven't")
        |> mes("eaten in days! Wait,")
        |> mes("hold on, you wouldn't")
        |> mes("happen to be Torpy's")
        |> mes("father now, would you?")
        |> next()
        |> mes("[Strange Man]")
        |> mes("Oh, you ran into my boy?")
        |> mes("Has he given up on our")
        |> mes("little wager yet? Because")
        |> mes("I'd really hate to lose...")
        |> next()

      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Um, your wife and son")
      |> mes("are really worried about")
      |> mes("you. Shouldn't you be going")
      |> mes("home as soon as you can?")
      |> next()
      |> mes("[Strange Man]")
      |> mes("No, I can't! Not until")
      |> mes("Torpy gives up! I made")
      |> mes("a really silly promise")
      |> mes("with my son, and if I lose")
      |> mes("this game of Hide-and-Seek...")
      |> mes("Well, I just can't lose! Bye!")
      |> set_char_var(:hg_ubu01, 6)
      |> changequest(12047, 12048)
      |> next()
      |> mes("^3355FFTorpy's father has")
      |> mes("hidden himself again,")
      |> mes("but at least now you")
      |> mes("can go back to Torpy's")
      |> mes("Mom and Torpy, and let them")
      |> mes("both know where he is hiding.^000000")
      |> close()
      |> disablenpc("Strange Man#Hugel")
      |> enablenpc("Suspicious Barrel")
    else
      ctx
      |> mes("[Strange Man]")
      |> mes("Hahahaha!")
      |> mes("Steamed Crab Nippers!")
      |> mes("That really hit the spot!")
      |> mes("I ate so much, I won't")
      |> mes("have to eat again for days!")
      |> close()
    end
  end
end
