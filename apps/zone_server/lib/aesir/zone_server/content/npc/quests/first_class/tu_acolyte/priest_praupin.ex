defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuAcolyte.PriestPraupin do
  @moduledoc """
  Priest Praupin of Prontera Church, who starts the Acolyte training quest and sends Acolytes
  to Sister Asthe's convent.

  ## Behavior

  - Introduces new Acolytes to Sister Asthe, starts the training quest, and offers a warp to
    the convent.
  - Accepts the receipt delivery and rewards a choice of Wand or Flail.
  - Offers the convent warp to Acolytes at most other quest steps, and bids farewell to those
    who finished the training.
  - Non-Acolytes get a blessing, or praise if they completed the training before changing job.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Jukka (fix up)
    - Lupus
    - SinSloth
    - L0ne_W0lf
    - Capuche
    - Euphy
    - Daegaladh
    - Joseph

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_church",
        x: 179,
        y: 15,
        dir: 1,
        sprite: 110,
        name: "Priest Praupin",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Priest Praupin]")

    if Rathena.job_id(base_job(ctx)) != Rathena.job_id(:acolyte) do
      greet_non_acolyte(ctx)
    else
      case get_char_var(ctx, :tu_acolyte01, 0) do
        0 -> start_training(ctx)
        7 -> point_to_bishop(ctx)
        22 -> receive_receipt(ctx)
        25 -> farewell(ctx)
        _ -> offer_convent_warp(ctx)
      end
    end
  end

  defp greet_non_acolyte(ctx) do
    ctx =
      if get_char_var(ctx, :tu_acolyte01, 0) == 25 do
        ctx
        |> mes("Oh...!")
        |> mes("You're #{char_name(ctx, 0)} !")
        |> mes("You've grown so much!")
        |> mes("I'm truly proud of you.")
      else
        ctx
        |> mes("May you")
        |> mes("always be blessed...")
      end

    close(ctx)
  end

  defp start_training(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Welcome, little one.")
      |> mes("Fate must have brought")
      |> mes("us together so that we'd")
      |> mes("meet today. It's nice to meet you.")
      |> next()
      |> mes("[Priest Praupin]")
      |> mes("But I am concerned that")
      |> mes("you may not know what to do")
      |> mes("as an Acolyte from here on...")
      |> next()
      |> select(["I'm not worried.", "What should I do?"])

    case choice do
      1 ->
        ctx
        |> mes("[Priest Praupin]")
        |> mes(
          "Seeing your eyes filled with such determination assures me. But if you run into any trouble, feel free to ask me for help. Good bye for now, blessed child."
        )
        |> close()

      2 ->
        introduce_asthe(ctx)

      _ ->
        point_to_bishop(ctx)
    end
  end

  defp introduce_asthe(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Priest Praupin]")
      |> mes("There is a convent northeast")
      |> mes(
        "of Prontera called the Saint Capitolina Convent. Go there and look for ^3131FF Sister Asthe^000000. She is a sweet and gentle soul who has"
      )
      |> mes("much to teach you.")
      |> next()
      |> mes("[Priest Praupin]")
      |> mes("I look forward to seeing you")
      |> mes(
        "become a better Acolyte after learning from Sister Asthe's instructions. If you like, I can send you to the convent."
      )
      |> set_char_var(:tu_acolyte01, 1)
      |> next()
      |> select(["Go to the convent.", "Do not go."])

    if choice == 1, do: send_to_convent(ctx), else: decline_warp(ctx)
  end

  defp point_to_bishop(ctx) do
    ctx
    |> mes("You're looking for someone")
    |> mes("that handles things with Archers")
    |> mes("at the church? Hmm...")
    |> next()
    |> mes("[Priest Praupin]")
    |> mes(
      "Ah, he's away at the convent right now. If you want to meet Bishop Maugins in the Saint Capitolina Convent, travel ^3131FFnorth^000000, ^3131FFeast^000000, ^3131FFeast^000000 and then ^3131FFeast^000000 from Prontera."
    )
    |> close()
  end

  defp receive_receipt(ctx) do
    if count_item(ctx, 7181) > 0 do
      {ctx, reward} =
        ctx
        |> emotion(:surprise)
        |> mes("Oh my, you seem")
        |> mes("to be growing quickly")
        |> mes("into your role as an Acolyte.")
        |> mes("Was the training difficult?")
        |> next()
        |> mes("[Priest Praupin]")
        |> mes("You have something")
        |> mes("to give me? Oh yes, the")
        |> mes("receipt! I was wondering")
        |> mes("what had happened. Thank")
        |> mes("you for all of your trouble.")
        |> next()
        |> mes("[Priest Praupin]")
        |> mes("Oh my, oh my.")
        |> mes("It's been a while.")
        |> mes("I wonder if there is")
        |> mes("anything I can give you?")
        |> next()
        |> mes("[Priest Praupin]")
        |> mes("How about one of these?")
        |> mes("I know I'm not offering much,")
        |> mes("but they were quite helpful to me when I was a young Acolyte like yourself.")
        |> next()
        |> select(["Wand", "Flail"])

      ctx = if reward == 1, do: give_item(ctx, 1604, 1), else: give_item(ctx, 1510, 1)

      ctx
      |> delitem(7181, 1)
      |> set_char_var(:tu_acolyte01, 23)
      |> close()
    else
      ctx
      |> mes("You are such a good person,")
      |> mes(
        "a true child of the light. I hope that many others will benefit from the purity of your heart and mind."
      )
      |> close()
    end
  end

  defp farewell(ctx) do
    ctx
    |> mes("You must now find")
    |> mes("your own path and become")
    |> mes("a better Acolyte using")
    |> mes("your own strength.")
    |> next()
    |> mes("[Priest Praupin]")
    |> mes(
      "I am worried, but I trust in your courage and affection. May you always be protected and may"
    )
    |> mes("you always be blessed.")
    |> close()
  end

  defp offer_convent_warp(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Sister Asthe in the Saint Capitolina Convent is such")
      |> mes("a sincere and loving person.")
      |> next()
      |> mes("[Priest Praupin]")
      |> mes(
        "Would you like me to send you to the convent so that you can learn from this wonderful teacher?"
      )
      |> next()
      |> select(["Yes, please.", "No thanks."])

    if choice == 1, do: send_to_convent(ctx), else: decline_warp(ctx)
  end

  defp send_to_convent(ctx) do
    ctx
    |> mes("[Priest Praupin]")
    |> mes("Please say hello")
    |> mes("to Sister Asthe for me.")
    |> mes("Have a safe trip, little one...")
    |> close()
    |> warp("prt_monk", 30, 250)
  end

  defp decline_warp(ctx) do
    ctx
    |> mes("[Priest Praupin]")
    |> mes("If you'd like,")
    |> mes("I can send you to")
    |> mes("the convent at anytime.")
    |> mes("Whenever you feel like")
    |> mes("you need help, come to me.")
    |> close()
  end
end
