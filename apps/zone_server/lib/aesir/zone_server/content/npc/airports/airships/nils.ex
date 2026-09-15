defmodule Aesir.ZoneServer.Content.Npc.Airports.Airships.Nils do
  @moduledoc """
  Hosts the RO Typing Challenge aboard the international airship.

  ## Behavior

  - Times two exact text-entry prompts selected at random.
  - Rejects incorrect entries and records qualifying server-wide high scores.
  - Explains the challenge and displays the current record holder.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "airplane_01",
        x: 32,
        y: 61,
        dir: 4,
        sprite: 49,
        name: "Nils",
        scope: :shared,
        unique_name: "Nils#ein",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @challenges [
    %{
      first_lines: [
        "^3cbcbccallipygian salacius lascivious^000000",
        "^3cbcbclicentious prurient concupiscent^000000",
        ""
      ],
      first_answer: "callipygian salacius lascivious licentious prurient concupiscent",
      second_lines: [
        "^3cbcbcuNflAPPaBLe LoVaBLe SeCreTs AnD^000000",
        "^3cbcbcboWLIiNg aGaINST tHe KarMA of YoUtH^000000"
      ],
      second_answer: "uNflAPPaBLe LoVaBLe SeCreTs AnD boWLIiNg aGaINST tHe KarMA of YoUtH",
      letters: 1300
    },
    %{
      first_lines: [
        "^3cbcbcBy the power of^000000",
        "^3cbcbcp-po-poi-po-poi-poin-poing^000000",
        "^3cbcbcGOD-POING. I NEVER LOSE!^000000"
      ],
      first_answer: "By the power of p-po-poi-po-poi-poin-poing GOD-POING. I NEVER LOSE!",
      second_lines: [
        "^ff1493LiGhTsPeEd RiGhT SPEed LeFT TURn^000000",
        "^ff1493RiGhT BuRn OrIGInAL GaNgSteR SmACk^000000"
      ],
      second_answer: "LiGhTsPeEd RiGhT SPEed LeFT TURn RiGhT BuRn OrIGInAL GaNgSteR SmACk",
      letters: 1250
    },
    %{
      first_lines: [
        "^0000ffthkelfkskeldmsiejdlslehfndkelsheidl^000000",
        "^3cbcbcskemd^000000",
        ""
      ],
      first_answer: "thkelfkskeldmsiejdlslehfndkelsheidlskemd",
      second_lines: ["^ff1493hfjdkeldjsieldjshfjdjeiskdlefvbd^000000", ""],
      second_answer: "hfjdkeldjsieldjshfjdjeiskdlefvbd",
      letters: 1180
    },
    %{
      first_lines: [
        "^3cbcbcburrdingdingdingdilidingdingdingphoohudaamb^000000",
        "^3cbcbcandoorabambarambambambambamburanbamding^000000",
        ""
      ],
      first_answer:
        "burrdingdingdingdilidingdingdingphoohudaambandoorabambarambambambambamburanbamding",
      second_lines: [
        "^ff1493burapaphuralanderamduanbatuhiwooi^000000",
        "^ff1493kabamturubamdingding^000000"
      ],
      second_answer: "burapaphuralanderamduanbatuhiwooikabamturubamdingding",
      letters: 1380
    },
    %{
      first_lines: [
        "^3cbcbcCoboman no chikara-yumei na^000000",
        "^3cbcbcchikara-daiookii na chikara da ze!^000000",
        "^3cbcbcCOBO ON^000000"
      ],
      first_answer: "Coboman no chikara-yumei na chikara-daiookii na chikara da ze! COBO ON",
      second_lines: [
        "^ff1493belief love luck grimace sweat rush^000000",
        "^ff1493folktale rodimus optimus bumblebee^000000"
      ],
      second_answer: "belief love luck grimace sweat rush folktale rodimus optimus bumblebee",
      letters: 1740
    },
    %{
      first_lines: [
        "^3cbcbcI'm the king of All Weirdos! Now^000000",
        "^3cbcbcyou know of my true power. Obey~!^000000",
        ""
      ],
      first_answer: "I'm the king of All Weirdos! Now you know of my true power. Obey~!",
      second_lines: [
        "^800080opeN, Open!op3n.openOpen0p3nOpEn0pen^000000",
        "^800080`open'0Pen open? open!111OPENSESAME^000000"
      ],
      second_answer: "opeN, Open!op3n.openOpen0p3nOpEn0pen`open'0Pen open? open!111OPENSESAME",
      letters: 1440
    },
    %{
      first_lines: [
        "^3cbcbcYou give me no choice. I guess it's^000000",
        "^3cbcbctime for me to reveal my secret...^000000",
        ""
      ],
      first_answer: "You give me no choice. I guess it's time for me to reveal my secret...",
      second_lines: [
        "^3cbcbcfReeDoM ecstAcy JoUrnaliSm ArMplt^000000",
        "^3cbcbcDisCoverY hEaDaChE MoonbeAmS jUsTiCE^000000"
      ],
      second_answer: "fReeDoM ecstAcy JoUrnaliSm ArMplt DisCoverY hEaDaChE MoonbeAmS jUsTiCE",
      letters: 1450
    }
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Nils]")
      |> mes("Welcome to the")
      |> mes("^ff0000RO Typing Challenge^000000.")
      |> mes("Would you like to play")
      |> mes("a quick typing game?")
      |> next()
      |> select([
        "Play ^ff0000RO Typing Challenge^000000",
        "Information",
        "View Top Records",
        "Cancel"
      ])

    case choice do
      1 -> play(ctx)
      2 -> explain(ctx)
      3 -> show_record(ctx)
      4 -> cancel(ctx)
      _ -> ctx
    end
  end

  defp play(ctx) do
    challenge = Enum.random(@challenges)

    ctx =
      ctx
      |> mes("[Nils]")
      |> mes("Okay, we have")
      |> mes("a new challenger!")
      |> mes("Enter the following")
      |> mes("text as quickly as you")
      |> mes("can without making any")
      |> mes("mistakes! Let's start~!")
      |> next()
      |> mes("[Nils]")
      |> show_lines(challenge.first_lines)

    first_started_at = gettimetick(ctx, 1)
    {ctx, first_entry} = ctx |> next() |> input(:string)
    first_finished_at = gettimetick(ctx, 1)

    ctx =
      ctx
      |> mes("[Nils]")
      |> show_lines(challenge.second_lines)

    second_started_at = gettimetick(ctx, 1)
    {ctx, second_entry} = ctx |> next() |> input(:string)
    second_finished_at = gettimetick(ctx, 1)

    total_time =
      first_finished_at - first_started_at + (second_started_at - second_finished_at)

    letters = div(challenge.letters, if(total_time > 0, do: total_time, else: 1)) * 6

    if first_entry == challenge.first_answer and second_entry == challenge.second_answer do
      record_result(ctx, total_time, letters)
    else
      incorrect_entry(ctx)
    end
  end

  defp show_lines(ctx, lines), do: Enum.reduce(lines, ctx, &mes(&2, &1))

  defp record_result(ctx, total_time, letters) do
    ctx =
      ctx
      |> mes("[Nils]")
      |> mes("Your record is ^ff0000#{total_time} seconds^000000 and")
      |> mes("the total letters are #{letters}.")
      |> next()

    cond do
      letters >= 1300 -> copied_text(ctx)
      letters >= get_server_var(ctx, "050320_ein_typing", 0) -> save_record(ctx, letters)
      true -> show_record(ctx)
    end
  end

  defp copied_text(ctx) do
    ctx
    |> mes("[Nils]")
    |> mes("Hmmm, this record isn't")
    |> mes("humanly possible unless you")
    |> mes("copy and paste the whole")
    |> mes("sentence. Please play fairly")
    |> mes("next time.")
    |> close()
  end

  defp save_record(ctx, letters) do
    previous_holder = get_server_var(ctx, "050320_minus1_typing$", "")
    previous_record = get_server_var(ctx, "050320_ein_typing", 0)
    player_name = char_name(ctx, 0)

    ctx
    |> mes("[Nils]")
    |> mes("The previous top record was")
    |> mes("made by ^0000ff#{previous_holder}^000000")
    |> mes("with the total ^0000ff#{previous_record}^000000 letters.")
    |> mes("However, ^ff0000#{player_name}^000000,")
    |> mes("you made the new top record")
    |> mes("this time. Congratulations!")
    |> set_server_var("050320_minus1_typing$", player_name)
    |> set_server_var("050320_ein_typing", letters)
    |> close()
  end

  defp incorrect_entry(ctx) do
    ctx
    |> mes("[Nils]")
    |> mes("Oooh...")
    |> mes("I'm sorry, but")
    |> mes("you entered the")
    |> mes("text incorrectly...")
    |> close()
  end

  defp explain(ctx) do
    ctx
    |> mes("[Nils]")
    |> mes("The ^ff0000RO Typing Challenge^000000")
    |> mes("is a game where you enter")
    |> mes("the given text as quickly as you")
    |> mes("can. The name of the top player")
    |> mes("is recorded for posterity. If you")
    |> mes("want fame, here's your chance!")
    |> next()
    |> mes("[Nils]")
    |> mes("I'd just like to let")
    |> mes("you know that you type")
    |> mes("all the text that you see")
    |> mes("in the single input line that")
    |> mes("you're given. So don't press")
    |> mes("the enter key, just click 'OK.'")
    |> close()
  end

  defp show_record(ctx) do
    record_holder = get_server_var(ctx, "050320_minus1_typing$", "")
    record = get_server_var(ctx, "050320_ein_typing", 0)

    ctx
    |> mes("[Nils]")
    |> mes("^0000ff#{record_holder}^000000")
    |> mes("is the current")
    |> mes("record holder with")
    |> mes("a letter total of ^0000ff#{record}^000000")
    |> mes("characters. Try to beat")
    |> mes("that record next time~")
    |> close()
  end

  defp cancel(ctx) do
    ctx
    |> mes("[Nils]")
    |> mes("Feel free to take on the")
    |> mes("^ff0000RO Typing Challenge^000000")
    |> mes("anytime. I'll be here~")
    |> close()
  end
end
