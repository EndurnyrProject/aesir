defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.SleipnirSeal.Manager do
  @moduledoc """
  Cukure manages the godly artifacts laboratory and opens and closes the Sleipnir Seal research.

  ## Behavior

  - Turns away overweight players and anyone below base level 70.
  - While the first Sleipnir seal is still sealed, she recruits the player as a temporary research
    assistant and hands over an admission pass; during the research she only chats.
  - When the research is finished, she advances the server's Sleipnir seal, announces when the
    seal appears or is released (or when all four seals are released together), and gives one
    random equipment piece from a mode-specific reward table.
  - Once the seal has been released, she only talks about the finished research.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_god01",
        x: 98,
        y: 98,
        dir: 4,
        sprite: 69,
        name: "Manager",
        scope: :shared,
        unique_name: "Manager#G"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @renewal_treasures [
    {101, [{210, 2102}, {420, 2104}, {630, 2106}, {840, 2108}, 2109]},
    {201,
     [
       {48, 2207},
       {96, 2210},
       {150, 2213},
       {190, 2215},
       {238, 2217},
       {290, 2223},
       {340, 2227},
       {348, 2229},
       {400, 2231},
       {448, 2233},
       {496, 2236},
       {544, 2244},
       {592, 2245},
       {640, 2247},
       {688, 2248},
       {736, 2250},
       {784, 2251},
       {832, 2252},
       {880, 2253},
       {940, 2257},
       2259
     ]},
    {301,
     [
       {160, 2267},
       {320, 2262},
       {480, 2263},
       {540, 2265},
       {700, 2266},
       {800, 2260},
       {900, 2269},
       2270
     ]},
    {401,
     [
       {70, 2298},
       {140, 2275},
       {210, 2276},
       {280, 2277},
       {350, 2279},
       {420, 2282},
       {490, 2299},
       {560, 2287},
       {630, 2289},
       {700, 2290},
       {770, 2291},
       {840, 2294},
       {900, 2295},
       {950, 2271},
       2285
     ]},
    {501,
     [
       {80, 2306},
       {160, 2308},
       {240, 2310},
       {320, 2311},
       {400, 2313},
       {480, 2315},
       {560, 2329},
       {630, 2320},
       {700, 2322},
       {760, 2324},
       {810, 2326},
       {850, 2342},
       {900, 2331},
       {950, 2333},
       2336
     ]},
    {601, [{200, 2402}, {400, 2404}, {600, 2406}, {800, 2407}, 2409]},
    {701, [{300, 2502}, {550, 2504}, {750, 2506}, 2508]},
    {801,
     [
       {110, 2601},
       {220, 2602},
       {330, 2603},
       {440, 2604},
       {550, 2605},
       {660, 2607},
       {770, 2608},
       {880, 2617},
       2618
     ]},
    [
      {150, 2288},
      {260, 2297},
      {370, 5087},
      {480, 5088},
      {590, 5089},
      {700, 5090},
      {810, 5046},
      {920, 2264},
      2225
    ]
  ]

  @classic_treasures [
    {101, [{210, 2102}, {420, 2104}, {630, 2106}, {840, 2108}, 2109]},
    {201,
     [
       {48, 2254},
       {96, 2210},
       {150, 2213},
       {190, 2255},
       {238, 2217},
       {290, 2223},
       {340, 2227},
       {348, 2229},
       {400, 2231},
       {448, 2233},
       {496, 5053},
       {544, 5019},
       {592, 2245},
       {640, 2247},
       {688, 2248},
       {736, 5166},
       {784, 5158},
       {832, 2249},
       {880, 5157},
       {940, 2285},
       5093
     ]},
    {301,
     [
       {160, 5014},
       {320, 5005},
       {480, 5054},
       {540, 2265},
       {700, 2266},
       {800, 2260},
       {900, 5113},
       2270
     ]},
    {401,
     [
       {70, 2286},
       {140, 5002},
       {210, 5147},
       {280, 2217},
       {350, 5120},
       {420, 2261},
       {490, 5162},
       {560, 5030},
       {630, 5109},
       {700, 5084},
       {770, 5168},
       {840, 2214},
       {900, 2295},
       {950, 5167},
       5018
     ]},
    {501,
     [
       {85, 2310},
       {170, 2311},
       {255, 2313},
       {340, 2317},
       {425, 2319},
       {510, 2320},
       {595, 2322},
       {680, 2359},
       {765, 2326},
       {850, 2342},
       {935, 2331},
       2336
     ]},
    {601, [{200, 2422}, {400, 2404}, {600, 2406}, {800, 2407}, 2412]},
    {701, [{200, 2513}, {400, 2504}, {600, 2506}, {800, 2514}, 2508]},
    {801,
     [
       {110, 1122},
       {220, 2622},
       {330, 2623},
       {440, 2624},
       {550, 2625},
       {660, 2607},
       {770, 2626},
       {880, 2617},
       2671
     ]},
    [
      {150, 2281},
      {260, 2297},
      {370, 5087},
      {480, 5088},
      {590, 5089},
      {700, 5090},
      {810, 5086},
      {920, 2292},
      5006
    ]
  ]

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{908, 500}]) == 0 ->
        ctx
        |> mes(
          "^3355FFWait a second! Right now, you're carrying too many items with you. Please come back after putting some of your things into Kafra Storage.^000000"
        )
        |> close()

      base_level(ctx) < 70 ->
        ctx |> busy_lament() |> close()

      get_server_var(ctx, "God1", 0) < get_server_temp_var(ctx, "god_check2", 0) ->
        research_open(ctx, get_char_var(ctx, :god_sl_1, 0))

      true ->
        ctx
        |> research_closed(get_char_var(ctx, :god_sl_1, 0))
        |> cutin("god_kukur01", 255)
    end
  end

  defp research_open(ctx, 0), do: ctx |> busy_lament() |> close()

  defp research_open(ctx, 1) do
    ctx
    |> mes("[Cukure]")
    |> mes(
      "We conduct research on godly artifacts that were left behind by the gods long ago. More specifically, we're interested in the tools the gods used."
    )
    |> next()
    |> mes("[Cukure]")
    |> mes(
      "Recently, many of the members of our research group, aside from the leaders, have left so now we're short on manpower."
    )
    |> next()
    |> mes("[Cukure]")
    |> mes(
      "Since we're understaffed, we can't continue most of our research projects that are currently in progress. Speaking of which..."
    )
    |> next()
    |> mes("[Cukure]")
    |> mes("Do you mind if I ask")
    |> mes("an adventurer like yourself")
    |> mes("to help us in our research?")
    |> next()
    |> mes("[Cukure]")
    |> mes(
      "We won't experiment on you or anything, we just need you to run some simple errands. And of course, you will be rewarded."
    )
    |> next()
    |> select(["I'm kind of busy...", "Sure, why not?"])
    |> answer_recruitment()
  end

  defp research_open(ctx, step), do: ctx |> research_progress(step) |> cutin("god_kukur01", 255)

  defp answer_recruitment({ctx, 1}) do
    ctx
    |> mes("[Cukure]")
    |> mes("Oh, I see.")
    |> mes(
      "Well, if you happen to find anyone that might work well as a temporary research assistant, would you recommend them to us?"
    )
    |> next()
    |> mes("[Cukure]")
    |> mes(
      "I'm so sorry to ask this of you, but I hope you understand that we're seriously lacking in terms"
    )
    |> mes("of human resources.")
    |> close()
  end

  defp answer_recruitment({ctx, 2}) do
    ctx
    |> cutin("god_kukur02", 2)
    |> mes("[Cukure]")
    |> mes("Really~?!")
    |> mes("That's great!")
    |> mes("Hahahahaha! I'm so")
    |> mes("glad to hear that!")
    |> next()
    |> mes("[Cukure]")
    |> mes(
      "Go inside and speak to the investigators there. They're all kind of swamped, so I'm sure they'll need your assistance."
    )
    |> next()
    |> mes("[Cukure]")
    |> mes("Oh, wait...")
    |> mes("Let me give you a temporary admission pass. Thank you")
    |> mes("so much for your help~")
    |> next()
    |> mes("^3355FFYou've received")
    |> mes("a temporary")
    |> mes("admission pass.^000000")
    |> set_char_var(:god_sl_1, 2)
    |> close2()
    |> cutin("god_kukur01", 255)
  end

  defp answer_recruitment({ctx, _choice}), do: ctx

  defp research_progress(ctx, step) when step < 10 do
    ctx
    |> cutin("god_kukur03", 2)
    |> mes("[Cukure]")
    |> mes(
      "It's really difficult to managing a laboratory. Rival labs always try to entice our staff away or interrupt our progress."
    )
    |> next()
    |> mes("[Cukure]")
    |> mes("And because of this job, it's really hard for me to enjoy")
    |> mes("having a personal life...")
    |> next()
    |> cutin("god_kukur02", 2)
    |> mes("[Cukure]")
    |> mes("Hahahaha...")
    |> mes("What am I doing?")
    |> mes(
      "Please just ignore what I just said. It's really not that big of a deal. ^333333*Sigh...*^000000"
    )
    |> close2()
  end

  defp research_progress(ctx, step) when step < 50 do
    ctx
    |> mes("[Cukure]")
    |> mes("Ah, thank you")
    |> mes("for helping us out.")
    |> mes("I hope you'll continue")
    |> mes("to lend us your assistance.")
    |> next()
    |> mes("[Cukure]")
    |> mes(
      "Although our researchers are kind of strange, they're all pretty nice and they mean well."
    )
    |> next()
    |> mes("[Cukure]")
    |> mes(
      "So I hope you understand if a few of them treat you in a way that seems kind of rude."
    )
    |> close2()
  end

  defp research_progress(ctx, 50) do
    ctx
    |> cutin("god_kukur02", 2)
    |> mes("[Cukure]")
    |> mes("Ah...")
    |> mes("You really helped us out a lot. Thank you for all you have done.")
    |> next()
    |> mes("[Cukure]")
    |> mes(
      "As you already know, we're trying to find out whether or not we can reproduce 'Sleipnir,' one of the tools used by the gods."
    )
    |> next()
    |> mes("[Cukure]")
    |> mes("However....")
    |> mes(
      "So far it seems impossible, at least with the technology that we currently have. Hmm..."
    )
    |> next()
    |> mes("[Cukure]")
    |> mes(
      "Anyways, we will continue to research and hope that we'll be able to accomplish our goal of recreating Sleipnir someday."
    )
    |> next()
    |> mes("[Cukure]")
    |> mes(
      "Thanks to you, we were able to complete a rudimentary study of Sleipnir. Now we can plan out a more advanced study of Sleipnir."
    )
    |> next()
    |> mes("[Cukure]")
    |> mes(
      "Before I forget, let me give you your reward for assisting in our research projects. Please give"
    )
    |> mes("me a minute...")
    |> next()
    |> mes("[Cukure]")
    |> mes("Ah, there it is.")
    |> mes(
      "It might not be much, but I hope you accept it as a token of my gratitude. Good luck on your travels!"
    )
    |> advance_seal()
    |> announce_seal()
    |> set_char_var(:god_sl_1, 51)
    |> set_local(:god_treasure, Enum.random(1..900))
    |> set_local(:god_treasure1, Enum.random(1..1000))
    |> give_treasure()
    |> next()
    |> mes("[Cukure]")
    |> mes(
      "Ah, I'll also need to take back that temporary pass I gave to you. I'm sorry, but it's protocol we have to follow..."
    )
    |> next()
    |> mes("[Cukure]")
    |> mes("Once again,")
    |> mes("thank you for")
    |> mes("all your help~")
    |> close2()
  end

  defp research_progress(ctx, _step) do
    ctx
    |> cutin("god_kukur02", 2)
    |> mes("[Cukure]")
    |> mes("With your assistance, we successfully completed our rudimentary study.")
    |> next()
    |> mes("[Cukure]")
    |> mes(
      "From now on, we'll plan out our more advanced studies based on the information we now have on the godly artifacts."
    )
    |> next()
    |> finally_a_date()
  end

  defp research_closed(ctx, 0), do: ctx |> cutin("god_kukur03", 2) |> busy_lament() |> close2()

  defp research_closed(ctx, step) when step < 51 do
    ctx
    |> mes("[Cukure]")
    |> mes("Ah, you've come back.")
    |> mes(
      "I know you were going to help us, but someone already applied for the assistant position."
    )
    |> next()
    |> mes("[Cukure]")
    |> mes(
      "Anyway, we've already finished our current research projects. Now, we're in the planning stages for the next projects we'll be conducting..."
    )
    |> next()
    |> mes("[Cukure]")
    |> mes(
      "Thank you anyway, though. I hope you will come and help us the next time we need assistance on our projects."
    )
    |> close2()
  end

  defp research_closed(ctx, _step) do
    ctx
    |> mes("[Cukure]")
    |> mes(
      "Now that we've completed our rudimentary studies, we'll simply plan out our future research projects."
    )
    |> next()
    |> finally_a_date()
  end

  defp busy_lament(ctx) do
    ctx
    |> mes("[Cukure]")
    |> mes(
      "I can't believe how busy I am at work nowadays. I don't even have time to see any of my friends or go shopping."
    )
    |> next()
    |> mes("[Cukure]")
    |> mes("Wait...!")
    |> mes("I can't even remember the last")
    |> mes(
      "time I went out with a guy! At this rate, I might retire before I can find a boyfriend. Noooo, I'm still in my prime~!"
    )
    |> emotion(:profusely_sweat)
  end

  defp finally_a_date(ctx) do
    ctx
    |> mes("[Cukure]")
    |> mes("Now that things")
    |> mes("have slowed down")
    |> mes("a little...")
    |> next()
    |> mes("[Cukure]")
    |> mes("I can finally")
    |> mes("go on a date!")
    |> mes("Hahahahahaha~!")
    |> close2()
  end

  defp advance_seal(ctx) do
    god1 = get_server_var(ctx, "God1", 0)

    if god1 < get_server_temp_var(ctx, "god_check2", 0),
      do: set_server_var(ctx, "God1", god1 + 1),
      else: ctx
  end

  defp announce_seal(ctx) do
    god1 = get_server_var(ctx, "God1", 0)
    released = get_server_temp_var(ctx, "god_check2", 0)

    cond do
      god1 == get_server_temp_var(ctx, "god_check1", 0) ->
        announce(ctx, "The 1st seal of [Sleipnir] has appeared.", 0)

      god1 == released and
          Enum.all?(["God2", "God3", "God4"], &(get_server_var(ctx, &1, 0) == released)) ->
        announce(
          ctx,
          "our seals have been released at the same time with the seal of [Sleipnir].",
          0
        )

      god1 == released ->
        announce(ctx, "The 1st seal of [Sleipnir] has been released.", 0)

      true ->
        ctx
    end
  end

  defp give_treasure(ctx) do
    treasures =
      if Rathena.truthy?(checkre(ctx, 0)), do: @renewal_treasures, else: @classic_treasures

    item =
      treasures
      |> first_below(get_local(ctx, :god_treasure, 0))
      |> first_below(get_local(ctx, :god_treasure1, 0))

    give_item(ctx, item, 1)
  end

  defp first_below([{bound, value} | _rest], roll) when roll < bound, do: value
  defp first_below([{_bound, _value} | rest], roll), do: first_below(rest, roll)
  defp first_below([fallback], _roll), do: fallback
end
