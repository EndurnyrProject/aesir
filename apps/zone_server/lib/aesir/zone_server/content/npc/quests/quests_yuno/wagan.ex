defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsYuno.Wagan do
  @moduledoc """
  Wagan seeks help stopping Metto’s disruptive research.

  ## Behavior

  - Starts the quest and rewards the player after Metto gives up.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - L0ne_W0lf
    - kobra_k88
    - Darkchild
    - Lupus
    - Samuray22
    - akrus

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_in01",
        x: 17,
        y: 30,
        dir: 5,
        sprite: 85,
        name: "Wagan",
        scope: :shared,
        unique_name: "Wagan#juno"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    ctx = mes(ctx, "[Wagan]")

    case get_char_var(ctx, :metto_q, 0) do
      0 ->
        start_quest(ctx)

      8 ->
        reward(ctx)

      9 ->
        ctx
        |> mes(
          "Things around here seem much more peaceful without that Metto around. Thanks for your help."
        )
        |> close()

      _ ->
        ctx
        |> mes(
          "How goes your work with Metto? Hopefully the plan is going well. I'm sorry to bother you with such a task."
        )
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp start_quest(ctx) do
    {ctx, choice} =
      ctx
      |> mes("I'm sure that you know our city has been living off our research for many years.")
      |> next()
      |> mes("[Wagan]")
      |> mes(
        "We owe this quality of life to those who have dedicated their lives to research and study."
      )
      |> next()
      |> mes("[Wagan]")
      |> mes(
        "So we help each other and study together. It is nice to have such solid support around when we are conducting research."
      )
      |> next()
      |> mes("[Wagan]")
      |> mes("But there are those few bad apples that just drive me crazy...")
      |> next()
      |> mes("[Wagan]")
      |> mes(
        "It's good to try hard, but there are those selfish and crazy mad scientists that make things harder for the rest of us."
      )
      |> next()
      |> mes("[Wagan]")
      |> mes(
        "Out of all those, ^FF0000Metto^000000 must be the worst by far. He's into crazy things..."
      )
      |> next()
      |> mes("[Wagan]")
      |> mes(
        "For science, he's destroyed public facilities, has been the cause of noise and air pollution and generally disturbing the peace..."
      )
      |> next()
      |> mes("[Wagan]")
      |> mes(
        "And he's justifying his behavior under the excuse of research! He's a crazy fellow who's taken it too far!"
      )
      |> next()
      |> mes("[Wagan]")
      |> mes(
        "I wish there was a way that we could stop him from wrecking it for the rest of us. Some brave, daring soul should be able to do something..."
      )
      |> next()
      |> select(["Leave it to me.", "I wish your village luck in doing so."])

    cond do
      choice != 1 ->
        ctx
        |> mes("[Wagan]")
        |> mes(
          "We will have to pray for fate to help us. Now to think of it, Metto is a strong believer in fate."
        )
        |> next()
        |> mes("[Wagan]")
        |> mes("If only we could use that to our advantage...")
        |> close()

      Rathena.job_id(class(ctx)) == Rathena.job_id(:novice) ->
        ctx
        |> mes("[Wagan]")
        |> mes("Hmm...")
        |> mes("Thanks for the offer, but I don't think this is something that you could do...")
        |> next()
        |> mes("[Wagan]")
        |> mes(
          "I think we need someone a bit harsher to help us out. I think it would be a little too much for a Novice."
        )
        |> next()
        |> mes("[Wagan]")
        |> mes("Please don't be")
        |> mes("offended by this.")
        |> close()

      true ->
        discuss_plan(ctx)
    end
  end

  defp discuss_plan(ctx) do
    {ctx, choice} =
      ctx
      |> set_char_var(:metto_q, 1)
      |> mes("[Wagan]")
      |> mes("Oh, are you going to take care of this for us? We would be very grateful.")
      |> next()
      |> mes("[Wagan]")
      |> mes(
        "But how do you plan to go about doing this? I'm guessing it's harder than it sounds..."
      )
      |> next()
      |> select(["Of course I have a plan.", "I guess I need a plan."])

    if choice == 1 do
      ctx
      |> mes("[Wagan]")
      |> mes(
        "I have faith in you. You should know that he believes in fate. Use that to your advantage."
      )
      |> next()
      |> mes("[Wagan]")
      |> mes("I feel much better knowing you will take care of this little problem...")
      |> close()
    else
      ctx
      |> mes("[Wagan]")
      |> mes(
        "Hmmm... I admire your zeal, but how do you expect to accomplish anything without a plan?"
      )
      |> next()
      |> mes("[Wagan]")
      |> mes("You need a ruse to trick him into quitting. Something subtle, like... Hmm...")
      |> next()
      |> mes("[Wagan]")
      |> mes("...Sabotaging his experiments and making it look like it was his destiny to fail!")
      |> next()
      |> mes("[Wagan]")
      |> mes("He's talkative, so if you approach him, he'll tell you all you need to know.")
      |> next()
      |> mes("[Wagan]")
      |> mes("Yeah...")
      |> mes("I've been thinking of this plan for a while...")
      |> close()
    end
  end

  defp reward(ctx) do
    ctx =
      ctx
      |> mes(
        "Thank you for your help. Because of your work in ridding us of Metto, we have one less worry."
      )
      |> next()
      |> mes("[Wagan]")
      |> mes(
        "I'm sure the people of Juno are very thankful. Here is a little token of our appreciation..."
      )
      |> next()
      |> mes("[Wagan]")

    if Rathena.job_id(class(ctx)) == Rathena.job_id(:sage) do
      if max_weight(ctx) - weight(ctx) < 300 do
        ctx
        |> mes("Oh no, it seems that you are carrying too much stuff! Would you make some room?")
        |> close()
      else
        ctx
        |> set_char_var(:metto_q, 9)
        |> mes("I wish you luck in your future endeavors...")
        |> give_item(715, 10)
        |> close()
      end
    else
      if max_weight(ctx) - weight(ctx) < 150 do
        ctx
        |> mes("Oh no, it seems that you are carrying too much! Would you make some room?")
        |> close()
      else
        ctx
        |> set_char_var(:metto_q, 9)
        |> mes("I wish you luck in your future endeavors...")
        |> give_item(717, 5)
        |> close()
      end
    end
  end
end
