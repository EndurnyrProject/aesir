defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.Toucan do
  @moduledoc """
  Toucan advances the Guarana Candy quest and blesses the adventurer.

  ## Behavior

  - Gives quest participants a feather, advances the quest, and warps them onward.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - og2
    - Euphy
    - Capuche
    - Daegaladh

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "bra_fild01",
        x: 75,
        y: 83,
        dir: 5,
        sprite: 2073,
        name: "Toucan",
        scope: :shared,
        unique_name: "Toucan#bra",
        trigger: {2, 2}
      }
    ]

  @impl true
  def on_event("OnTouch", ctx) do
    talk_to_animal(ctx)
  end

  @impl true
  def on_talk(ctx) do
    talk_to_animal(ctx)
  end

  defp talk_to_animal(ctx) do
    if get_char_var(ctx, :brazil_gua, 0) == 6 do
      {ctx, _} =
        ctx
        |> mes("[Toucan]")
        |> mes("Baaeecc!")
        |> mes("I've never seen you before.")
        |> mes("Baaeec!")
        |> next()
        |> mes("[Toucan]")
        |> mes(
          "It's the middle of the new and old continent... I know I've never seen you before but you seem familiar, like a woman dancing a samba. "
        )
        |> next()
        |> select(["What are you talking about?"])

      {ctx, _} =
        ctx
        |> mes("[Toucan]")
        |> mes("I can feel some similar power like guarana kid. bbaaaeeeccc!")
        |> next()
        |> mes("[Toucan]")
        |> mes(
          "That kid has had a really lonely time, baaecc! Perhaps you are a friend of him? Baaeec!!"
        )
        |> next()
        |> select(["Not yet... but I want to be a friend."])

      {ctx, _} =
        ctx
        |> mes("[Toucan]")
        |> mes(
          "The kid who received care from guarana woman is also a friend of animals. Bbaaeecc!"
        )
        |> next()
        |> mes("[Toucan]")
        |> mes("I'd like to give the symbol of a toucan representative for the kid. Bbaaeecc!")
        |> next()
        |> mes("[Toucan]")
        |> mes("If you want to relieve his loneliness, can you help me?")
        |> next()
        |> select(["Absolutely!"])

      ctx
      |> mes("[Toucan]")
      |> mes("It's my feather.")
      |> mes("Send it to the kid.")
      |> mes(
        "We will keep our promise of friendship between guarana kid and Toucan forever. Bbaaeecc!"
      )
      |> next()
      |> mes("- You take a feather from Toucan. - ")
      |> next()
      |> mes("[Toucan]")
      |> mes("There have to be others around here like me.")
      |> mes("Why don't you find a jaguar Bbaaeecc!")
      |> next()
      |> mes("[Toucan]")
      |> mes("I will give a blessing from Toucan to you.")
      |> next()
      |> mes("[Toucan]")
      |> mes("Fly fly far away. bbaaaeeeccckkk--!")
      |> set_char_var(:brazil_gua, 7)
      |> changequest(2196, 2197)
      |> specialeffect2(:seismicweapon)
      |> close()
      |> warp("bra_fild01", 68, 146)
    else
      ctx |> mes("[Toucan]") |> mes("Bbbaaeec~! Baaeec~!") |> close()
    end
  end
end
