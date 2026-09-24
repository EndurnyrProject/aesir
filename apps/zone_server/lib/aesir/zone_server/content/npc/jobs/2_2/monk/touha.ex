defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Monk.Touha do
  @moduledoc """
  Monk who teaches Monk candidates a prayer and quizzes them on reciting it.

  ## Behavior

  - Greets candidates sent by Sensei Moohae and starts the recitation lesson once they are ready.
  - Recites one of three prayers line by line, then has the candidate rebuild it from ten menus.
  - Sends candidates who recite every line correctly on to Boohae; others must try again.
  - Reminds candidates who already passed to visit Boohae, and otherwise recites the monk's creed.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Dino9021
    - Celest
    - L0ne_W0lf
    - Samuray22
    - Kisuka
    - Lupus
    - Yor
    - Zephiris
    - Vicious
    - Silent

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_monk",
        x: 251,
        y: 255,
        dir: 1,
        sprite: 79,
        name: "Touha",
        scope: :shared,
        unique_name: "Touha#mk"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @seek_the_path [
    "I seek the path",
    "of enlightenment.",
    "We monks",
    "shall hold true",
    "to what we believe",
    "and will help protect others",
    "through the teachings",
    "we learn through our lives.",
    "In nomine Patris, et Filii",
    "et Spiritus Sancti."
  ]

  @commit_myself [
    "I commit myself to",
    "veritas and aequitas.",
    "I will follow my path",
    "to enlightenment and purity.",
    "I will protect my",
    "brothers with my life.",
    "Evil shall never be",
    "victorious while I breathe.",
    "In nomine Patris, et Filii",
    "et Spiritus Sancti."
  ]

  @shepherds [
    "And shepherds we shall be,",
    "for thee my lord for thee.",
    "Power hath descended forth",
    "from the hand",
    "so our feet may swiftly carry",
    "out thy command. And we shall",
    "flow a river forth to thee and",
    "teeming with souls shall it ever be",
    "In nomine Patris, et Filii",
    "et Spiritus Sancti."
  ]

  @seek_the_path_menus [
    [
      "shall hold true",
      "We monks",
      "and will help protect others",
      "through the teachings",
      "In nomine Patris, et Filii",
      "to what we believe",
      "I seek the path",
      "we learn through our lives.",
      "et Spiritus Sancti.",
      "of enlightenment."
    ],
    [
      "We monks",
      "In nomine Patris, et Filii",
      "I seek the path",
      "shall hold true",
      "of enlightenment.",
      "and will help protect others",
      "we learn through our lives.",
      "through the teachings",
      "to what we believe",
      "et Spiritus Sancti."
    ],
    [
      "to what we believe",
      "We monks",
      "I seek the path",
      "shall hold true",
      "of enlightenment.",
      "we learn through our lives.",
      "In nomine Patris, et Filii",
      "and will help protect others",
      "through the teachings",
      "et Spiritus Sancti."
    ],
    [
      "shall hold true",
      "I seek the path",
      "We monks",
      "In nomine Patris, et Filii",
      "of enlightenment.",
      "et Spiritus Sancti.",
      "to what we believe",
      "we learn through our lives.",
      "and will help protect others",
      "through the teachings"
    ],
    [
      "of enlightenment.",
      "I seek the path",
      "We monks",
      "shall hold true",
      "and will help protect others",
      "through the teachings",
      "we learn through our lives.",
      "In nomine Patris, et Filii",
      "to what we believe",
      "et Spiritus Sancti."
    ],
    [
      "I seek the path",
      "through the teachings",
      "and will help protect others",
      "of enlightenment.",
      "shall hold true",
      "et Spiritus Sancti.",
      "In nomine Patris, et Filii",
      "to what we believe",
      "We monks",
      "we learn through our lives."
    ],
    [
      "we learn through our lives.",
      "In nomine Patris, et Filii",
      "et Spiritus Sancti.",
      "I seek the path",
      "of enlightenment.",
      "to what we believe",
      "We monks",
      "shall hold true",
      "and will help protect others",
      "through the teachings"
    ],
    [
      "we learn through our lives.",
      "In nomine Patris, et Filii",
      "through the teachings",
      "I seek the path",
      "We monks",
      "shall hold true",
      "to what we believe",
      "and will help protect others",
      "of enlightenment.",
      "et Spiritus Sancti."
    ],
    [
      "I seek the path",
      "of enlightenment.",
      "We monks",
      "shall hold true",
      "to what we believe",
      "et Spiritus Sancti.",
      "and will help protect others",
      "through the teachings",
      "we learn through our lives.",
      "In nomine Patris, et Filii"
    ],
    [
      "I seek the path",
      "of enlightenment.",
      "We monks",
      "shall hold true",
      "to what we believe",
      "and will help protect others",
      "through the teachings",
      "we learn through our lives.",
      "In nomine Patris, et Filii",
      "et Spiritus Sancti."
    ]
  ]

  @commit_myself_menus [
    [
      "I will follow my path",
      "veritas and aequitas.",
      "to enlightenment and purity.",
      "I commit myself to",
      "I will protect my",
      "victorious while I breathe.",
      "brothers with my life.",
      "Evil shall never be",
      "In nomine Patris, et Filii",
      "et Spiritus Sancti."
    ],
    [
      "I will follow my path",
      "I will protect my",
      "brothers with my life.",
      "to enlightenment and purity.",
      "Evil shall never be",
      "victorious while I breathe.",
      "et Spiritus Sancti.",
      "I commit myself to",
      "veritas and aequitas.",
      "In nomine Patris, et Filii"
    ],
    [
      "I will follow my path",
      "veritas and aequitas.",
      "I commit myself to",
      "et Spiritus Sancti.",
      "Evil shall never be",
      "to enlightenment and purity.",
      "In nomine Patris, et Filii",
      "I will protect my",
      "brothers with my life.",
      "victorious while I breathe."
    ],
    [
      "veritas and aequitas.",
      "Evil shall never be",
      "I will follow my path",
      "I will protect my",
      "victorious while I breathe.",
      "to enlightenment and purity.",
      "brothers with my life.",
      "In nomine Patris, et Filii",
      "et Spiritus Sancti.",
      "I commit myself to"
    ],
    [
      "victorious while I breathe.",
      "I commit myself to",
      "to enlightenment and purity.",
      "brothers with my life.",
      "Evil shall never be",
      "In nomine Patris, et Filii",
      "et Spiritus Sancti.",
      "I will follow my path",
      "veritas and aequitas.",
      "I will protect my"
    ],
    [
      "to enlightenment and purity.",
      "I will follow my path",
      "veritas and aequitas.",
      "I commit myself to",
      "brothers with my life.",
      "I will protect my",
      "victorious while I breathe.",
      "Evil shall never be",
      "et Spiritus Sancti.",
      "In nomine Patris, et Filii"
    ],
    [
      "veritas and aequitas.",
      "Evil shall never be",
      "brothers with my life.",
      "victorious while I breathe.",
      "I will follow my path",
      "to enlightenment and purity.",
      "I will protect my",
      "In nomine Patris, et Filii",
      "et Spiritus Sancti.",
      "I commit myself to"
    ],
    [
      "victorious while I breathe.",
      "to enlightenment and purity.",
      "I will protect my",
      "veritas and aequitas.",
      "brothers with my life.",
      "I will follow my path",
      "Evil shall never be",
      "In nomine Patris, et Filii",
      "I commit myself to",
      "et Spiritus Sancti."
    ],
    [
      "I commit myself to",
      "I will follow my path",
      "veritas and aequitas.",
      "I will protect my",
      "to enlightenment and purity.",
      "brothers with my life.",
      "Evil shall never be",
      "In nomine Patris, et Filii",
      "victorious while I breathe.",
      "et Spiritus Sancti."
    ],
    [
      "I commit myself to",
      "veritas and aequitas.",
      "I will follow my path",
      "to enlightenment and purity.",
      "I will protect my",
      "brothers with my life.",
      "Evil shall never be",
      "victorious while I breathe.",
      "In nomine Patris, et Filii",
      "et Spiritus Sancti."
    ]
  ]

  @shepherds_menus [
    [
      "for thee my lord for thee.",
      "And shepherds we shall be,",
      "Power hath descended forth",
      "out thy command. And we shall",
      "from the hand",
      "flow a river forth to thee and",
      "so our feet may swiftly carry",
      "teeming with souls shall it ever be",
      "et Spiritus Sancti.",
      "In nomine Patris, et Filii"
    ],
    [
      "teeming with souls shall it ever be",
      "flow a river forth to thee and",
      "so our feet may swiftly carry",
      "In nomine Patris, et Filii",
      "et Spiritus Sancti.",
      "Power hath descended forth",
      "And shepherds we shall be,",
      "for thee my lord for thee.",
      "from the hand",
      "out thy command. And we shall"
    ],
    [
      "And shepherds we shall be,",
      "for thee my lord for thee.",
      "Power hath descended forth",
      "from the hand",
      "teeming with souls shall it ever be",
      "et Spiritus Sancti.",
      "In nomine Patris, et Filii",
      "so our feet may swiftly carry",
      "out thy command. And we shall",
      "flow a river forth to thee and"
    ],
    [
      "for thee my lord for thee.",
      "And shepherds we shall be,",
      "Power hath descended forth",
      "so our feet may swiftly carry",
      "from the hand",
      "flow a river forth to thee and",
      "out thy command. And we shall",
      "In nomine Patris, et Filii",
      "teeming with souls shall it ever be",
      "et Spiritus Sancti."
    ],
    [
      "And shepherds we shall be,",
      "for thee my lord for thee.",
      "Power hath descended forth",
      "so our feet may swiftly carry",
      "from the hand",
      "so our feet may swiftly carry",
      "flow a river forth to thee and",
      "In nomine Patris, et Filii",
      "teeming with souls shall it ever be",
      "et Spiritus Sancti."
    ],
    [
      "for thee my lord for thee.",
      "Power hath descended forth",
      "And shepherds we shall be,",
      "from the hand",
      "so our feet may swiftly carry",
      "flow a river forth to thee and",
      "out thy command. And we shall",
      "teeming with souls shall it ever be",
      "In nomine Patris, et Filii",
      "et Spiritus Sancti."
    ],
    [
      "for thee my lord for thee.",
      "teeming with souls shall it ever be",
      "flow a river forth to thee and",
      "In nomine Patris, et Filii",
      "et Spiritus Sancti.",
      "Power hath descended forth",
      "And shepherds we shall be,",
      "so our feet may swiftly carry",
      "from the hand",
      "out thy command. And we shall"
    ],
    [
      "teeming with souls shall it ever be",
      "In nomine Patris, et Filii",
      "And shepherds we shall be,",
      "for thee my lord for thee.",
      "Power hath descended forth",
      "from the hand",
      "so our feet may swiftly carry",
      "out thy command. And we shall",
      "flow a river forth to thee and",
      "et Spiritus Sancti."
    ],
    [
      "Power hath descended forth",
      "for thee my lord for thee.",
      "And shepherds we shall be,",
      "In nomine Patris, et Filii",
      "so our feet may swiftly carry",
      "from the hand",
      "teeming with souls shall it ever be",
      "flow a river forth to thee and",
      "out thy command. And we shall",
      "et Spiritus Sancti."
    ],
    [
      "And shepherds we shall be,",
      "for thee my lord for thee.",
      "Power hath descended forth",
      "from the hand",
      "out thy command. And we shall",
      "so our feet may swiftly carry",
      "flow a river forth to thee and",
      "teeming with souls shall it ever be",
      "In nomine Patris, et Filii",
      "et Spiritus Sancti."
    ]
  ]

  @prayers [
    {11, {@seek_the_path, @seek_the_path_menus}},
    {12, {@commit_myself, @commit_myself_menus}},
    {13, {@shepherds, @shepherds_menus}}
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    quest = get_char_var(ctx, :MONK_Q, 0)

    cond do
      quest >= 10 and quest < 14 ->
        recitation_lesson(ctx, quest)

      quest == 14 ->
        ctx
        |> mes("[Touha]")
        |> mes("Hmm... did you forget who to visit?")
        |> next()
        |> mes("[Touha]")
        |> mes("I wonder about your abilities if you cannot remember such a simple thing.")
        |> next()
        |> mes("[Touha]")
        |> mes("...are you testing my patience?")
        |> next()
        |> mes("[Touha]")
        |> mes("You wear my patience thin...")
        |> mes("... go visit Boohae.")
        |> close()

      quest > 14 and Rathena.job_id(base_job(ctx)) == Rathena.job_id(:acolyte) ->
        ctx |> mes("[Touha]") |> mes("...do your best for the final test.") |> close()

      true ->
        ctx
        |> mes("[Touha]")
        |> mes("Never shall innocent blood be shed.")
        |> next()
        |> mes("[Touha]")
        |> mes("Yet the blood of the wicked shall flow like a river.")
        |> next()
        |> mes("[Touha]")
        |> mes("We shall spread our blackened wings and be the vengeful striking hammer of god.")
        |> next()
        |> mes("[Touha]")
        |> mes("We shall flow a river forth to thee, and teeming with souls shall it ever be.")
        |> next()
        |> mes("[Touha]")
        |> mes("In nomine Patris, et Filii, et Spiritus Sancti.")
        |> next()
        |> mes("[Touha]")
        |> mes("...You don't have to be afraid of me...")
        |> close()
    end
  end

  defp recitation_lesson(ctx, quest) when quest == 10 do
    {ctx, choice} =
      ctx
      |> mes("[Touha]")
      |> mes("What brings you to me.")
      |> mes("Do you wish to share a conversation with me?")
      |> next()
      |> mes("[Touha]")
      |> mes("Oh, I see. You're on the monk in training.")
      |> mes("You already possess a similar spirit as a monk's.")
      |> next()
      |> mes("[Touha]")
      |> mes("By the looks of you, it seems, you")
      |> mes("have already visited Sensei Moohae. Good.")
      |> next()
      |> mes("[Touha]")
      |> mes("Let me inform you about certain things you must know as a monk.")
      |> mes(
        "Then I will help you to strengthen your body so that you can bear your next training."
      )
      |> next()
      |> mes("[Touha]")
      |> mes("Calm your mind.")
      |> mes("Relax your body...are you ready?")
      |> next()
      |> select(["Yes.", "No."])

    if choice == 2 do
      ctx |> mes("[Touha]") |> mes("Please come back when you're ready.") |> close()
    else
      ctx
      |> mes("[Touha]")
      |> mes("Ok...then.")
      |> next()
      |> mes("[Touha]")
      |> mes("Please repeat after me.")
      |> next()
      |> changequest(3024, 3025)
      |> recite_and_quiz()
    end
  end

  defp recitation_lesson(ctx, _quest) do
    ctx
    |> mes("[Touha]")
    |> mes("Now, pay attention this time...")
    |> next()
    |> recite_and_quiz()
  end

  defp recite_and_quiz(ctx) do
    ctx = mes(ctx, "[Touha]")
    roll = Enum.random(1..3)
    rand = if halted?(ctx), do: 0, else: roll
    quest = get_char_var(ctx, :MONK_Q, 0)

    prayer_id =
      cond do
        rand == 1 or quest == 11 -> 11
        rand == 2 or quest == 12 -> 12
        rand == 3 or quest == 13 -> 13
        true -> nil
      end

    ctx =
      case prayer(prayer_id) do
        {lines, _menus} -> ctx |> set_char_var(:MONK_Q, prayer_id) |> recite(lines) |> next()
        nil -> next(ctx)
      end

    ctx =
      if get_char_var(ctx, :MONK_Q, 0) == 10 do
        ctx
        |> mes("[Touha]")
        |> mes("Ok, that is all. Now repeat what I have spoken.")
        |> mes(Rathena.concat(Rathena.concat("", char_name(ctx, 0)), ", your turn."))
        |> next()
      else
        ctx
      end

    {ctx, score} =
      case prayer(get_char_var(ctx, :MONK_Q, 0)) do
        {lines, menus} -> quiz(ctx, lines, menus)
        nil -> {ctx, 0}
      end

    ctx
    |> next()
    |> mes("[Touha]")
    |> mes("...")
    |> next()
    |> mes("[Touha]")
    |> mes("Hmm...")
    |> next()
    |> judge(score)
  end

  defp prayer(quest), do: Enum.find_value(@prayers, fn {id, prayer} -> quest == id && prayer end)

  defp recite(ctx, [first | rest]) do
    Enum.reduce(rest, mes(ctx, first), fn line, ctx ->
      ctx |> next() |> mes("[Touha]") |> mes(line)
    end)
  end

  defp quiz(ctx, lines, menus) do
    menus
    |> Enum.zip(lines)
    |> Enum.with_index()
    |> Enum.reduce({ctx, 0}, fn {{options, answer}, index}, {ctx, score} ->
      {ctx, choice} = select(ctx, options)
      answer_line(ctx, score, options, choice, answer, index == 0)
    end)
  end

  defp answer_line(ctx, score, options, choice, answer, first?)
       when choice in 1..length(options)//1 do
    picked = Enum.at(options, choice - 1)
    score = if picked == answer and not halted?(ctx), do: score + 10, else: score

    ctx =
      if first?,
        do: mes(ctx, Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]")),
        else: ctx

    {mes(ctx, picked), score}
  end

  defp answer_line(ctx, score, _options, _choice, _answer, _first?), do: {ctx, score}

  defp judge(ctx, score) when score > 90 do
    ctx
    |> set_char_var(:MONK_Q, 14)
    |> changequest(3025, 3026)
    |> mes("[Touha]")
    |> mes("...well done, that was perfect. You pay attention well...")
    |> next()
    |> mes("[Touha]")
    |> mes("However, now is not the time to relax. Your path is still long ahead of you.")
    |> next()
    |> mes("[Touha]")
    |> mes("Now as I promised, I will help strengthen your body.")
    |> next()
    |> mes("Focus your mind and do not move.")
    |> next()
    |> mes("^33CCFFYou feel wind all around your body.^000000")
    |> next()
    |> mes("^33CCFFAn energy within you grows.^000000")
    |> next()
    |> mes("[Touha]")
    |> mes("I feel what grows within you.")
    |> mes("You may now continue on...")
    |> next()
    |> mes("[Touha]")
    |> mes("...the next course will be with Boohae.")
    |> next()
    |> mes("[Touha]")
    |> mes("I wish you well on your journey.")
    |> mes("Don't forget, his name is ^CC0000Boohae^000000.")
    |> close()
  end

  defp judge(ctx, _score) do
    ctx
    |> mes("[Touha]")
    |> mes(
      "I see you did not pay attention.. If you wish to become a monk, you must take this seriously."
    )
    |> next()
    |> mes("[Touha]")
    |> mes("Perhaps the path of a monk is too difficult for you?")
    |> mes("You must take this seriously if you wish to continue...")
    |> next()
    |> mes("[Touha]")
    |> mes("I will give you another chance.")
    |> next()
    |> mes("[Touha]")
    |> mes(
      "If you cannot pay attention and repeat what I ask you to, I will not allow you to continue your training here.."
    )
    |> close()
  end

  defp halted?(%{status: {:error, _}}), do: true
  defp halted?(_ctx), do: false
end
