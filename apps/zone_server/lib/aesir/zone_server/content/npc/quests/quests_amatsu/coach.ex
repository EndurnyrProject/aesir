defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.Coach do
  @moduledoc """
  Concludes the Momotaro challenge or offers a final battle.

  ## Behavior

  - Advances the quest and returns the player, or starts the final battle.

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
        y: 100,
        dir: 3,
        sprite: 762,
        name: "Coach",
        scope: :shared,
        unique_name: "Coach#ama",
        trigger: {15, 15}
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Coach#ama")

  def on_event("OnTouch_", ctx) do
    ctx |> mes("[Coach]") |> mes("Boom bam Boooom!!!") |> mes("Tada~~~ !") |> close()
  end

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Coach]")
      |> mes("Hoho~ Good.")
      |> mes("I've been watching you in the VIP room. You were really something.")
      |> mes("I was truly amazed.")
      |> next()
      |> mes("[Coach]")
      |> mes("I thought you were really")
      |> mes("Momotaro in the story!")
      |> mes("Hohohoho...")
      |> next()
      |> select(["Well, well. It is nothing~", "It was boring."])

    case choice do
      1 ->
        ctx
        |> mes("[Coach]")
        |> mes("...Hohoho..")
        |> mes("Don't be so proud of yourself.")
        |> mes("When I was young like you,")
        |> mes("I squashed Dokebi with")
        |> mes("my little finger. Hohoho~")
        |> next()
        |> mes("[Coach]")
        |> mes("..............")
        |> mes("...Don't give me that look.")
        |> mes("I was just joking. Hmmhmm.")
        |> next()
        |> changequest(8127, 8128)
        |> mes("[Coach]")
        |> mes("Now, the Momotaro story is over.")
        |> mes("You can get your reward when you talk to the Publisher lady you saw first.")
        |> next()
        |> mes("[Coach]")
        |> mes("Don't lose your high self-esteem")
        |> mes("in the future. Farewell.")
        |> close()
        |> donpcevent("Timer#ama::OnDisable")
        |> warp("amatsu", 223, 230)
        |> disablenpc("Coach#ama")
        |> donpcevent("Assistant#ama::OnReset")

      2 ->
        {ctx, challenge_choice} =
          ctx
          |> mes("[Coach]")
          |> mes(".....!!!!!!")
          |> mes("....Hohohoho..")
          |> mes("You're pretty funny.")
          |> mes("Alright, hot stuff.")
          |> mes("Do you want to listen to my proposal?")
          |> next()
          |> changequest(8127, 8129)
          |> mes("[Coach]")
          |> mes("At this point I'm supposed to send you back...BUT!")
          |> mes("I really want to know")
          |> mes("what you are capable of. Hehe~")
          |> mes("Hohoho~")
          |> next()
          |> mes("[Coach]")
          |> mes("So, I will give you a chance.")
          |> mes("But if you fail,")
          |> mes("^3163FFyou can't take this challenge.^000000")
          |> mes("Also, this mission will be pretty hard.")
          |> next()
          |> select(["Nah.. I'm good.", "Bring it on, foo'!"])

        if challenge_choice == 1 do
          ctx
          |> erasequest(8129)
          |> mes("[Coach]")
          |> mes("Hoho~I understand...")
          |> mes(
            "You must be exhausted from the previous battle. It would have been a grand battle, though..."
          )
          |> next()
          |> mes("[Coach]")
          |> mes("Now, the Momotaro story is over.")
          |> mes("You can get your reward")
          |> mes("when you talk to")
          |> mes("the Publisher lady you first spoke to.")
          |> next()
          |> mes("[Coach]")
          |> mes("Don't lose your high self-esteem")
          |> mes("in the future. Farewell.")
          |> next()
          |> setquest(8128)
          |> warp("amatsu", 223, 230)
          |> disablenpc("Coach#ama")
          |> donpcevent("Timer#ama::OnDisable")
          |> donpcevent("Assistant#ama::OnReset")
        else
          ctx
          |> mes("[Coach]")
          |> mes("Hohoho~ I like your attitude.")
          |> mes("Now, this is the last battle!")
          |> mes("Show me what you got.")
          |> mes("I'm looking forward to this.")
          |> percent_heal(hp: 70, sp: 0)
          |> disablenpc("Coach#ama")
          |> donpcevent("Am Mut#ama::OnEnable")
          |> close()
        end

      _ ->
        ctx
    end
  end
end
