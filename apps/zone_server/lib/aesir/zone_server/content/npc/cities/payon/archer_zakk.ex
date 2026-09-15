defmodule Aesir.ZoneServer.Content.Npc.Cities.Payon.ArcherZakk do
  @moduledoc """
  Talks about Payon's chief and his motormouthed archer friend Wolt.

  ## Behavior

  - Answers questions about his friend, Payon's chief, or the meaning of motormouth.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad Dib
    - Darkchild
    - DracoRPG
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "payon_in01",
        x: 66,
        y: 64,
        dir: 5,
        sprite: 88,
        name: "Archer Zakk",
        scope: :shared,
        unique_name: "Archer Zakk#payon"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Archer Zakk]")
      |> mes("I'm kind of worried")
      |> mes("about one of my pals.")
      |> next()
      |> mes("[Archer Zakk]")
      |> mes(
        "Even though he's an expert at archery, no one likes his motor mouth. Even our chief is getting fed up with him!"
      )
      |> next()
      |> select(["Your friend?", "Payon has a chief?", " Motor... Mouth?"])

    ctx
    |> answer_topic(choice)
    |> close()
  end

  defp answer_topic(ctx, 1) do
    ctx
    |> mes("[Archer Zakk]")
    |> mes("Ah, right. This buddy of mine is the number one archer in Payon.")
    |> mes(
      "He teaches newbie Archers around the Archer Village. It might be a good idea to talk to him at least once."
    )
  end

  defp answer_topic(ctx, 2) do
    ctx
    |> mes("[Archer Zakk]")
    |> mes(
      "Our chief lives in the Central Palace. I guess you can say that he's the spiritual guide of Payon."
    )
    |> next()
    |> mes("[Archer Zakk]")
    |> mes(
      "He used to menace the monsters in Payon Forest, carrying his Gakkung. I remember watching him fight when I was just a little kid."
    )
    |> next()
    |> mes("[Archer Zakk]")
    |> mes("But now he")
    |> mes("seems old and weak.")
    |> mes("Still, his eyes are as sharp as they used to be during his days")
    |> mes("of battle, where he'd never miss")
    |> mes("a target.")
    |> next()
    |> mes("[Archer Zakk]")
    |> mes("I admire our chief")
    |> mes("from the bottom")
    |> mes("of my heart. ")
  end

  defp answer_topic(ctx, 3) do
    ctx
    |> mes("[Archer Zakk]")
    |> mes("You don't know")
    |> mes("what a motormouth is...?")
    |> next()
    |> mes("[Archer Zakk]")
    |> mes("Motormouth")
    |> mes("Noun. Some fool who chatters")
    |> mes("way too much about stuff that doesn't really matter and doesn't know when to stop.")
    |> next()
    |> mes("[Archer Zakk]")
    |> mes("But yeah, my pal is not only")
    |> mes(
      "a legend at archery, he's also well known for how long he's let that mouth of his run."
    )
    |> next()
    |> mes("[Archer Zakk]")
    |> mes("Anyway, my pal Wolt doesn't have")
    |> mes(
      "a place of his own, so he stays at the Inn. Why don't you go and meet him? He's actually an okay guy if you can stand all the chatter."
    )
  end

  defp answer_topic(ctx, _choice), do: ctx
end
