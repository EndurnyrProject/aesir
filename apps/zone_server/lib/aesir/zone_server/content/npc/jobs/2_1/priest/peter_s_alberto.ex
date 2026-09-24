defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Priest.PeterSAlberto do
  @moduledoc """
  Father Peter, who runs the second trial of the Priest job quest, the spiritual training.

  ## Behavior

  - Explains the spiritual training to Acolytes who finished the pilgrimage and sends them
    into the training hall, advancing the quest log.
  - Lets Acolytes postpone or leave the training and come back later to start it.
  - Sends Priests into the training hall to assist an Acolyte.
  - Sends anyone else back to Prontera.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Pgro Team (OwNaGe)
    - kobra_k88
    - Lupus
    - Vicious
    - KarLaeda
    - L0ne_W0lf
    - Samuray22
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "job_prist",
        x: 24,
        y: 187,
        dir: 4,
        sprite: 110,
        name: "Peter S. Alberto",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnEnable", ctx), do: enablenpc(ctx, "Peter S. Alberto")
  def on_event("OnDisable", ctx), do: disablenpc(ctx, "Peter S. Alberto")

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Father Peter]")

    if Rathena.job_id(base_job(ctx)) == Rathena.job_id(:priest) do
      greet_priest(ctx)
    else
      guide_acolyte(ctx)
    end
  end

  defp greet_priest(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Welcome!")
      |> mes("#{sibling_title(ctx)} #{char_name(ctx, 0)}!")
      |> mes("So good to see you again!")
      |> next()
      |> mes("[Father Peter]")
      |> mes(
        "Are you here to help an Acolyte friend for the spiritual training? That's great~ I think you'll do a good job."
      )
      |> next()
      |> mes("[Father Peter]")
      |> mes(
        "Remember, no matter how much you want to help this Acolyte, this is not your quest."
      )
      |> next()
      |> mes("[Father Peter]")
      |> mes(
        "You may assist and lighten your friend's burden, but you take upon this task for yourself."
      )
      |> next()
      |> mes("[Father Peter]")
      |> mes("So...")
      |> mes("Are you gonna help him right now?")
      |> next()
      |> select(["Yes, I am.", "Give me a minute.", "I changed my mind."])

    case choice do
      1 ->
        ctx
        |> mes("[Father Peter]")
        |> mes(
          "Go for it! As your Acolyte enters, the test will begin. Now, I will send you to the testing area."
        )
        |> close()
        |> warp("job_prist", 24, 44)

      2 ->
        ctx
        |> mes("[Father Peter]")
        |> mes("Hm...?")
        |> mes("What for?")
        |> mes("Well, so long as you arrive in time to help your friend, it will be okay.")
        |> close()

      3 ->
        ctx
        |> mes("[Father Peter]")
        |> mes("Oh...?")
        |> mes("Then please,")
        |> mes("go ahead. God bless")
        |> mes("you, and take care!")
        |> close()
        |> warp("prontera", 234, 318)

      _ ->
        guide_acolyte(ctx)
    end
  end

  defp guide_acolyte(ctx) do
    quest = get_char_var(ctx, :PRIEST_Q, 0)

    cond do
      quest == 5 -> introduce_training(ctx)
      quest == 6 -> offer_training_again(ctx)
      true -> ctx |> mes("Go back!") |> close() |> warp("prontera", 234, 318)
    end
  end

  defp introduce_training(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Welcome~!")
      |> mes("I congratulate you")
      |> mes("for passing the first trail.")
      |> next()
      |> mes("[Father Peter]")
      |> mes("My name is")
      |> mes("Peter S. Alberto.")
      |> mes("How is my buddy Paul?")
      |> mes("Is he doing alright")
      |> mes("these days?")
      |> next()
      |> mes("[Father Peter]")
      |> mes(
        "Oh, I keep forgetting that he was promoted to Bishop. I think I'm supposed to call him Bishop Paul, or 'His Excellency.' Haha~"
      )
      |> next()
      |> mes("[Father Peter]")
      |> mes(
        "Anyway, let me give you a brief explanation of the spiritual training. Are you familiar with what the spiritual training is for Priests?"
      )
      |> next()
      |> select(["Yes, I do.", "Sorry..."])

    ctx =
      case choice do
        1 ->
          ctx
          |> mes("[Father Peter]")
          |> mes(
            "Haha, I like you! But it never hurts to have too much information. The more well informed you are, the more easily you'll pass the test!"
          )
          |> next()

        2 ->
          ctx
          |> mes("[Father Peter]")
          |> mes(
            "Oh, no need to be sorry. I'm here to give you the information you need anyway. So, don't worry."
          )
          |> next()

        _ ->
          ctx
      end

    {ctx, choice} =
      ctx
      |> mes("[Father Peter]")
      |> mes(
        "In spiritual training, you will be defeating evil creatures. Creatures of the Undead and Demons are all evil. In choosing to serve darkness, they are our enemies!"
      )
      |> next()
      |> mes("[Father Peter]")
      |> mes(
        "There are too many evil creatures that roam this world against the will of God. Innocents suffer as a result of their malignance."
      )
      |> next()
      |> mes("[Father Peter]")
      |> mes(
        "We, as Priests, are obligated to exterminate all those creatures, thus spreading love and peace."
      )
      |> next()
      |> mes("[Father Peter]")
      |> mes(
        "This training will test your ability to eliminate evil. Since this trial is pretty difficult to be accomplished by yourself,"
      )
      |> mes("I recommend getting help from a Priest if you can.")
      |> next()
      |> mes("[Father Peter]")
      |> mes(
        "If you are close to a Priest, you'd better ask him to assist you during this trial. Now, are you ready?"
      )
      |> next()
      |> select(["I'm ready.", "Please hold on.", "I want to go back."])

    case choice do
      1 ->
        ctx
        |> mes("[Father Peter]")
        |> mes(
          "Now, let the spiritual training begin. It's simple. Just kill them all. Show no mercy to the creatures of darkness!"
        )
        |> next()
        |> mes("[Father Peter]")
        |> mes("Now...")
        |> mes("Go for it!")
        |> close()
        |> enter_training()

      2 ->
        ctx |> set_char_var(:PRIEST_Q, 6) |> allow_time()

      3 ->
        ctx |> set_char_var(:PRIEST_Q, 6) |> send_back()

      _ ->
        ctx
    end
  end

  defp offer_training_again(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Are you ready this time?")
      |> mes("Complete this trial quickly,")
      |> mes("and become a Priest!")
      |> next()
      |> mes("[Father Peter]")
      |> mes("Are you ready then?")
      |> next()
      |> select(["I'm ready.", "Please hold on.", "I want to go back."])

    case choice do
      1 ->
        ctx
        |> mes("[Father Peter]")
        |> mes(
          "Now, let the spiritual training begin. For the glory of God, for peace on earth, and goodwill towards all men..."
        )
        |> next()
        |> mes("[Father Peter]")
        |> mes("Go...")
        |> mes("Kill those")
        |> mes("misbegotten creatures!")
        |> close()
        |> enter_training()

      2 ->
        allow_time(ctx)

      3 ->
        send_back(ctx)

      _ ->
        ctx
    end
  end

  defp enter_training(ctx) do
    ctx =
      if checkquest(ctx, 8012) == -1 do
        changequest(ctx, 8011, 8012)
      else
        ctx
      end

    ctx
    |> warp("job_prist", 24, 44)
    |> donpcevent("Zombie_Generator#prst::OnEnable")
    |> donpcevent("Peter S. Alberto::OnDisable")
    |> donpcevent("Peter S. Alberto#2::OnEnable")
  end

  defp allow_time(ctx) do
    ctx
    |> mes("[Father Peter]")
    |> mes("Hm? What is it you need?")
    |> mes("Well, no problem. You can")
    |> mes("afford to take your time.")
    |> close()
  end

  defp send_back(ctx) do
    ctx
    |> mes("[Father Peter]")
    |> mes("What...?")
    |> mes("You wanna go back??")
    |> next()
    |> mes("[Father Peter]")
    |> mes(
      "I understand. I suppose you have some important reason or business that you must attend to. Come back whenever you can."
    )
    |> close()
    |> warp("prontera", 234, 318)
  end

  defp sibling_title(ctx) do
    if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0), do: "Brother", else: "Sister"
  end
end
