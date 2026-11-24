defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.Grandma22111 do
  @moduledoc """
  Confronts the fox possessing Ishida Saoko.

  ## Behavior

  - Attempts an exorcism with chances based on job and carried items.
  - Advances the quest on success or sends the player away on failure.

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
        map: "ama_in01",
        x: 22,
        y: 111,
        dir: 0,
        sprite: 761,
        name: "Grandma",
        scope: :shared,
        unique_name: "Grandma#ama2"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :event_amatsu, 0) do
      4 -> exorcise(ctx)
      5 -> recovered(ctx)
      6 -> story(ctx)
      _ -> possessed(ctx)
    end
  end

  defp exorcise(ctx) do
    {ctx, _} =
      ctx
      |> mes("[....]")
      |> mes("^FF6060Yelp, Yelp, a foolish human")
      |> mes("again! What are you going to do")
      |> mes("to get rid of me!?^000000")
      |> next()
      |> mes("[....]")
      |> mes("^FF6060You look like you learned")
      |> mes("something from somewhere, but")
      |> mes("it won't harm me!! Yelp!^000000")
      |> next()
      |> select(["Taaaah!!"])

    priest? = Rathena.job_id(base_job(ctx)) == Rathena.job_id(:priest)

    fox_kill =
      cond do
        priest? ->
          if Enum.random(1..4) == 1, do: 0, else: 1

        Rathena.job_id(base_job(ctx)) == Rathena.job_id(:acolyte) or
          Rathena.job_id(base_job(ctx)) == Rathena.job_id(:monk) or
          count_item(ctx, 523) > 0 or count_item(ctx, 948) > 0 or
            count_item(ctx, 1029) > 0 ->
          if Enum.random(1..2) == 1, do: 0, else: 1

        true ->
          if Enum.random(1..4) == 1, do: 1, else: 0
      end

    ctx = set_local(ctx, :fox_kill, fox_kill)

    if get_local(ctx, :fox_kill, 0) == 1 do
      ctx
      |> mes("[....]")
      |> mes("^FF6060Yelp! Yelp! Yelp! Human!")
      |> mes("To expel me from this body like")
      |> mes("this! Curse you! Darn you!!^000000")
      |> next()
      |> mes("[....]")
      |> mes("^FF6060I will curse the Ishida family")
      |> mes("who made me like this! Forever!")
      |> mes("You better watch out, human!^000000")
      |> next()
      |> summon_mob(mob_id: 1180, map: "ama_in01", at: {22, 111}, name: "Nine Tails")
      |> killmonsterall("ama_in01")
      |> set_char_var(:event_amatsu, 5)
      |> changequest(8134, 8135)
      |> give_item(1022, 1)
      |> mes("[....]")
      |> mes("^FF6060Everything that")
      |> mes("Yoshinaga does will cause you")
      |> mes("unhappiness...^000000")
      |> mes("^FF0000Yaaaaaaaaaaaaap!!^000000")
      |> close()
    else
      ctx
      |> mes("[....]")
      |> mes("^FF6060Yelp! Haha! Yelp! Hahaha!")
      |> mes("Are you trying to expel me from this body!?")
      |> mes("Shoo!! Yelp!^000000")
      |> close()
      |> warp("amatsu", 167, 197)
    end
  end

  defp recovered(ctx) do
    ctx
    |> mes("[Ishida Saoko]")
    |> mes("...Huh? Why are you here...?")
    |> mes("*Urrmmm* My head hurts...")
    |> mes("But I'm starting to remember everything...")
    |> next()
    |> mes("[Ishida Saoko]")
    |> mes("Thank you, traveler from a far off")
    |> mes("land. I owe you a great debt... Thank you very much...")
    |> next()
    |> mes("[Ishida Saoko]")
    |> mes("I will tell my son that")
    |> mes("you exorcised the fox...")
    |> mes("Thank you...")
    |> next()
    |> mes("[Ishida Saoko]")
    |> mes("I should get some rest.")
    |> mes("My head aches, Young one.....")
    |> mes("Go to my son...")
    |> close()
  end

  defp story(ctx) do
    ctx
    |> mes("[Ishida Saoko]")
    |> mes("Oh, Are you...? You are the one")
    |> mes("who exorcised the fox... Welcome.")
    |> mes("Please, have a seat...")
    |> next()
    |> mes("[Ishida Saoko]")
    |> mes("When I think over, being possessed")
    |> mes("by the fox was my fault. I raised")
    |> mes("my son badly... Oh~")
    |> mes("He was a good boy when he was")
    |> mes("young. I wasn't strict to him...")
    |> next()
    |> mes("[Ishida Saoko]")
    |> mes("Long ago, this town wasn't as big")
    |> mes("as it is today. There was no big")
    |> mes("palace like Toukoujyo. Then, one")
    |> mes("day, my son brought great riches")
    |> mes("to the village. He never told me what he did to earn that fortune...")
    |> next()
    |> mes("[Ishida Saoko]")
    |> mes("He built the palace and helped")
    |> mes("the towners and make the town bigger.")
    |> mes("He was perfect until...")
    |> mes("he started doing strange things.")
    |> next()
    |> mes("[Ishida Saoko]")
    |> mes("Things...which angered God.")
    |> mes("He learned forbidden magic,")
    |> mes("performed experiments")
    |> mes("in the palace, caged monsters,")
    |> mes("did all sorts of horrible things...")
    |> next()
    |> mes("[Ishida Saoko]")
    |> mes("That is the reason why there are")
    |> mes("monsters in Toukoujyo... Finally,")
    |> mes("God's wrath was unleashed. Even the Priest in the shrine couldn't help...")
    |> next()
    |> mes("[Ishida Saoko]")
    |> mes("At last, the anger came toward")
    |> mes("me...It seems God tried to warn my son with the fox.")
    |> mes("However, my son won't stop.")
    |> next()
    |> mes("[Ishida Saoko]")
    |> mes("If it is okay, please stop my son.")
    |> mes("I don't have much time.")
    |> mes("I don't know what to do...")
    |> mes("Please save this peaceful village.")
    |> mes("I beg you please...")
    |> mes("What is he truly thinking...?")
    |> close()
  end

  defp possessed(ctx) do
    ctx
    |> mes("[....]")
    |> mes("^FF6060Yelp, Yelp, Another foolish human!")
    |> mes("Yelp, Yelp, Who! Human!?")
    |> mes("What are you doing!")
    |> mes("Shoo... Yelp! Yelp!^000000")
    |> next()
    |> mes("[....]")
    |> mes("^FF6060I will be in here until")
    |> mes("the Ishida family line dies out!")
    |> mes("Don't disturb me! Yelp!^000000")
    |> close()
    |> warp("amatsu", 167, 197)
  end
end
