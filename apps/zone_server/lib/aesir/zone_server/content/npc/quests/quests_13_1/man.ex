defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Man do
  @moduledoc """
  The blood-covered man in the ruined eastern Morocc, who turns out to be the corrupted Rayan
  Moore.

  ## Behavior

  - On `mao_morocc2` step 19 reveals the blood-covered man, brings Mr. Kidd in, and plays the
    unmasking of Rayan Moore through the portrait changes, advancing quest 7028 to 7029 and
    setting the step to 20 before warping the player to the save point.
  - On every other step the man attacks, closing the dialog and taking 100 HP.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_dan02",
        x: 115,
        y: 53,
        dir: 3,
        sprite: 456,
        name: "Man",
        scope: :shared,
        unique_name: "Man#moc2_crazyR01"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :mao_morocc2, 0) == 19 do
      reveal_rayan(ctx)
    else
      servant_of_his_master(ctx)
    end
  end

  defp reveal_rayan(ctx) do
    ctx =
      ctx
      |> mes("A man covered in blood is standing at a corner with a mysterious grin.")
      |> next()
      |> donpcevent("Mr. Kidd#moc_extra01::OnEnable")
      |> mes("[Mr. Kidd]")
      |> mes("I guess it was the right timing.")
      |> mes("By the way, who is this guy?")
      |> mes("He looks kind of.. He's insane, isn't he?")
      |> cutin("mocseal_kid01", 0)
      |> next()
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Woah! Where did you come from?")
      |> next()
      |> mes("[Mr. Kidd]")
      |> mes("...From somewhere.")
      |> mes("Anyways...")
      |> mes("What happened?")
      |> mes("Who are you?")
      |> next()
      |> cutin("moc2_dan01", 2)
      |> mes("[Man]")
      |> mes("...Who am I...?")
      |> mes("...I think I forgot...")
      |> mes("They're all dead.. I've killed them.")
      |> mes("Hehehe, I just followed the will of my master.")
      |> mes("Muhahahahaha!!")
      |> next()

    {ctx, _} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("No... No way!")
      |> next()
      |> select(["Rayan?!"])

    ctx
    |> cutin("moc2_kid02", 0)
    |> mes("[Mr. Kidd]")
    |> mes("What? Is this really the Rayan we've been chasing?")
    |> mes("..... !!!")
    |> mes("Right, you said Rayan was having a dispute with his buddies..")
    |> next()
    |> cutin("moc2_dan02", 2)
    |> mes("[Rayan]")
    |> mes("...Ray... Rayan? That's my name? That's right...")
    |> mes("I'm Rayan. Rayan Moore.")
    |> mes("Who are you..?")
    |> next()
    |> mes("[Rayan]")
    |> mes("Where am I? What's all this blood?!")
    |> mes("...Huh? Where am I? What happened to my friends?")
    |> next()
    |> cutin("mocseal_kid01", 0)
    |> mes("[Mr. Kidd]")
    |> mes("...I guess I was right. He really is Rayan Moore.")
    |> mes("What's wrong with him?")
    |> mes("He seems... He seems really confused. Maybe even unstable.")
    |> next()
    |> mes("[Mr. Kidd]")
    |> mes("Well, it's the perfect time to capture this guy before he can kill us.")
    |> mes(
      "Rin will know if this is the real Rayan because I've never seen him without his mask.."
    )
    |> next()
    |> mes("[Mr. Kidd]")
    |> mes("I'll bring this guy to Rin so she can interrogate him.")
    |> mes("I'll see you at the camp.")
    |> cutin("mocseal_kid01", 255)
    |> next()
    |> mes(
      "- You watched Mr. Kidd arrest the unconscious Rayan and take out a teleportation item. You decide to return to town. -"
    )
    |> set_char_var(:mao_morocc2, 20)
    |> changequest(7028, 7029)
    |> close()
    |> warp(:save_point)
    |> donpcevent("Mr. Kidd#moc_extra01::OnDisable")
    |> cutin("mocseal_kid01", 255)
  end

  defp servant_of_his_master(ctx) do
    ctx
    |> mes("[Man]")
    |> mes("I live to serve my master!")
    |> mes("Are you his enemy?")
    |> mes("DIE!")
    |> close()
    |> percent_heal(hp: -100, sp: 0)
  end
end
