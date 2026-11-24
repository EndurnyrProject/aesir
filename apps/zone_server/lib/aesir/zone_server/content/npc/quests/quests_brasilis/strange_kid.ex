defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.StrangeKid do
  @moduledoc """
  The strange kid helps adventurers find guarana for the Candy Maker.

  ## Behavior

  - Talks with adventurers during the guarana quest and gives them a berry.

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
        map: "brasilis",
        x: 203,
        y: 64,
        dir: 3,
        sprite: 706,
        name: "Strange Kid",
        scope: :shared,
        unique_name: "Strange Kid#bra"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :brazil_gua, 0) do
      stage when stage < 3 ->
        silent(ctx)

      3 ->
        talk_to_kid(ctx)

      4 ->
        seek_advice(ctx)

      stage when stage > 4 and stage < 9 ->
        ctx |> mes("[Strange Kid]") |> mes("Ah...? ah.....?") |> close()

      9 ->
        receive_berry(ctx)

      10 ->
        replace_berry(ctx)

      _ ->
        ctx |> mes("- The kid is smiling. -") |> close()
    end
  end

  defp silent(ctx), do: ctx |> mes("[Strange Kid]") |> mes("................") |> close()

  defp talk_to_kid(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Strange Kid]")
      |> mes("................")
      |> next()
      |> select(["Try to talk.", "Pretend to pass by."])

    if choice == 2 do
      silent(ctx)
    else
      ctx |> mes("What can I say to him?") |> next() |> conversation()
    end
  end

  defp seek_advice(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("He makes strange sounds like an animal.")
    |> mes("Should I ask advice from Cherto?")
    |> close()
  end

  defp receive_berry(ctx) do
    ctx = ctx |> mes("[Strange Kid]") |> mes("ah... ahah.....") |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("I don't have a story but there are lots of friends waiting outside.")
      |> next()
      |> mes("- You give the feather, fresh meat and branch of grapes to the kid -")
      |> next()
      |> mes("[Strange Kid]")
      |> mes("Ah.............")
      |> next()
      |> mes("[Strange Kid]")
      |> mes("Un, uhh....")
      |> mes("mooo... mommy.....")
      |> next()
      |> mes("[Strange Kid]")
      |> mes("Ah..........")
      |> mes("bird....")
      |> mes("mon, mon, mon...key......")
      |> mes("boo, booow...........")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Dog?!")
      |> mes("kkk yes. Lots of friends want to meet you.")
      |> mes("Don't be lonely anymore and be happy with your friends.")
      |> next()
      |> mes("[Strange Kid]")
      |> mes("ah....he...hehe....")
      |> next()
      |> mes("- He starts to smile lightly and laughs. -")
      |> next()
      |> mes("[Strange Kid]")
      |> mes("Ye......yes.......")
      |> mes("tha... than......thank......yo.........you.")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Alright such a cute smile!")
      |> mes("Be a happy kid as always.")
      |> next()
      |> mes("[Strange Kid]")
      |> mes("Uh......")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("what?")
      |> next()
      |> mes("[Strange Kid]")
      |> mes("hey..........")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Do you want to say anything?")
      |> next()
      |> mes("- You get closer and pretend to take caution. -")
      |> next()
      |> emotion(:chup)
      |> mes("(kiss~)")
      |> next()
      |> mes("- The kid laughs again lightly then puts something in your hand. -")
      |> next()
      |> mes("- It's a fresh berry that's colored red and hard. -")
      |> next()
      |> mes("[Strange Kid]")
      |> mes("ga...ra..........na...")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Oops, guarana berry?")
      |> mes("Ah! Thank you very much!")

    ctx =
      ctx
      |> emotion(:chupchup, playerattached(ctx))
      |> emotion(:smile)
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("If I have this, I can make a guarana candy.")
    |> mes("I better find that Candy Maker!")
    |> set_char_var(:brazil_gua, 10)
    |> changequest(2199, 2200)
    |> give_item(6237, 1)
    |> close()
  end

  defp replace_berry(ctx) do
    if not Rathena.truthy?(count_item(ctx, 6237)) do
      ctx |> mes("[Strange Kid]") |> mes("He.........") |> give_item(6237, 1) |> close()
    else
      ctx
    end
  end

  defp conversation(ctx) do
    {ctx, choice} =
      select(ctx, [
        "What's your name?",
        "How old are you?",
        "What are you doing?",
        "End conversation."
      ])

    case choice do
      1 ->
        ctx
        |> mes("[Strange Kid]")
        |> mes("Kaaaaaaao~")
        |> mes("Grrrrrrrrr - kaaan-")
        |> next()
        |> conversation()

      2 ->
        ctx
        |> mes("[Strange Kid]")
        |> mes("Booooowoooooo-")
        |> mes("Booooowoooooo- -")
        |> next()
        |> conversation()

      3 ->
        ctx
        |> mes("[Strange Kid]")
        |> mes("chamber pot braeee chamber pot brae chamber pot brae -")
        |> mes("Bbeeeebbeee -")
        |> next()
        |> conversation()

      4 ->
        finish_conversation(ctx)

      _ ->
        ctx
    end
  end

  defp finish_conversation(ctx) do
    ctx = ctx |> mes("[Strange Kid]") |> mes("Kaaaaaaao~") |> mes("Grrrrrrrrr - kaaan-") |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("He makes strange sound like an animals.")
    |> mes("Should I ask advice from Cherto?")
    |> set_char_var(:brazil_gua, 4)
    |> changequest(2193, 2194)
    |> close()
  end
end
