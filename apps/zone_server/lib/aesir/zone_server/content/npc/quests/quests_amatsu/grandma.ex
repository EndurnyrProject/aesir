defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.Grandma do
  @moduledoc """
  Asks Momotaro to defeat the Dokebi.

  ## Behavior

  - Starts the quest and selects the Dokebi encounter based on carried items.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - MasterOfMuppets
    - L0ne_W0lf
    - Gepard
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ama_test",
        x: 50,
        y: 93,
        dir: 4,
        sprite: 761,
        name: "Grandma",
        scope: :shared,
        unique_name: "Grandma#ama1",
        trigger: {10, 10}
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  def on_event("OnTouch_", ctx), do: ev_ontouch(ctx)
  @impl true
  def on_talk(ctx) do
    ctx
  end

  defp ev_oninit(ctx) do
    disablenpc(ctx, "Grandma#ama1")
  end

  defp ev_ontouch(ctx) do
    ctx =
      ctx
      |> mes("[Grandma]")
      |> mes("Arrrk!!!")
      |> next()
      |> mes("[Grandma]")
      |> mes("Honey!! Someone hacked my account and stole my equipment!! ")
      |> next()
      |> mes("[Grandpa]")
      |> mes("Hmm. The Chief said Dokebi earned 20 million zeny by hacking others' accounts...")
      |> next()
      |> setquest(8127)
      |> mes("[Grandma]")
      |> mes("Dohhhhhhh!!!! ")
      |> next()
      |> mes("[Grandpa]")
      |> mes("....Huh I've heard that somewhere.. ..... ")
      |> next()
      |> mes("[Grandpa]")
      |> mes("Anyway, Momotaro...")
      |> next()
      |> mes("[Grandpa]")
      |> mes("As you know, since we towners spend our time sitting and chatting,")
      |> mes("we can't kill Dokebis because we're low level, so...Please do it for us. ")
      |> next()
      |> mes("[Grandma]")
      |> mes("Momotaro...")
      |> mes("I really wanted to give you")
      |> mes("a handmade ^3163FFYummiest Red Potion in the whole world^000000 ...but...")
      |> mes(".....I failed to make them ....")
      |> next()
      |> mes("[Grandma]")
      |> mes("...I'm sorry. I should have been leveling up before...*Sob*")
      |> next()
      |> mes("[Grandma & Grandpa]")
      |> mes("So...Do me this favor, kid~")
      |> close()
      |> set_char_var(:event_momo, 1)

    event =
      if count_item(ctx, 9010) > 0 or count_item(ctx, 9005) > 0 or count_item(ctx, 9016) > 0 do
        "Dokebi#ez::OnEnable"
      else
        "Dokebi#hd::OnEnable"
      end

    ctx
    |> disablenpc("Grandpa#ama")
    |> disablenpc("Grandma#ama1")
    |> donpcevent(event)
  end
end
