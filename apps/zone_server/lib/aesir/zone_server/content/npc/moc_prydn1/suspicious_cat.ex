defmodule Aesir.ZoneServer.Content.Npc.MocPrydn1.SuspiciousCat do
  @moduledoc """
  The "Suspicious Cat#night2" quest NPC, hand-ported from rAthena
  `npc/re/quests/quests_morocc.txt:122` (`moc_prydn1,94,98`).

  Two parallel hunting chains that each turn into a cooldown quest on completion:

  * Eliminate Verit -- hunt 20 `N_VERIT` (quest `2289`), then `changequest`
    `2289 -> 2290` (the cooldown quest) and `getexp 300000, 100000`.
  * Eliminate Ancient Mummy -- hunt 20 `N_ANCIENT_MUMMY` (quest `2292`), then
    `changequest 2292 -> 2291` and `getexp 600000, 200000`.

  A third menu option warps back to the Thief Guild; the last just closes.

  ## Porting notes

  * **Hand-ported, not transpiled.** `mix aesir.import.npcs` over
    `quests_morocc.txt` would drag in every unrelated NPC in that file and fight
    the transpile manifest, so this single acceptance NPC is ported directly.
  * **`close2 -> warp` becomes `close -> warp`.** rAthena's `close2` shows the
    dialog, blocks on the close button, then continues the script; the DSL has
    no blocking-then-continue close, so the "Go back" branch flushes a `close`
    frame and then warps. The player still ends up at the Thief Guild; only the
    "wait for the button" beat is dropped.
  * **PLAYTIME cooldown stays locked after turn-in.** Our `checkquest(_,
    :playtime)` never reports "expired" (the time-limit mechanic is deferred),
    so once a chain is turned in the cooldown quest keeps the "we're safe for a
    while" branch active and the hunt cannot be re-accepted. This mirrors the
    upstream script literally and is the spec-accepted consequence.
  """

  use Aesir.ZoneServer.Npc,
    spawn: [%{map: "moc_prydn1", x: 94, y: 98, dir: 3, sprite: 547, name: "Suspicious Cat"}]

  @verit_hunt 2289
  @verit_cooldown 2290
  @mummy_hunt 2292
  @mummy_cooldown 2291

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Suspicious Cat]")
      |> mes(
        "That stupid mummy slapped me again while you were looking away! Sniff sniff... Let's go back, meow!"
      )
      |> next()
      |> select([
        "Go back to Thief Guild",
        "Eliminate Verit",
        "Eliminate Ancient Mummy",
        "It's nothing"
      ])

    case choice do
      1 -> go_back(ctx)
      2 -> verit_chain(ctx)
      3 -> mummy_chain(ctx)
      _ -> close(ctx)
    end
  end

  defp go_back(ctx) do
    ctx
    |> mes("[Suspicious Cat]")
    |> mes("Right right... let's go back.")
    |> close()
    |> warp("moc_prydb1", 100, 57)
  end

  defp verit_chain(ctx) do
    case checkquest(ctx, @verit_cooldown, :playtime) do
      playtime when playtime in [0, 1] ->
        ctx
        |> mes("[Suspicious Cat]")
        |> mes(
          "Look at that Verit, he's afraid of us! Kyaahaha! We're safe, at least for a while!"
        )
        |> close()

      2 ->
        ctx |> erasequest(@verit_cooldown) |> verit_hunting()

      _not_started ->
        verit_hunting(ctx)
    end
  end

  defp verit_hunting(ctx) do
    case checkquest(ctx, @verit_hunt, :hunting) do
      -1 -> verit_offer(ctx)
      hunting when hunting in [0, 1] -> verit_in_progress(ctx)
      2 -> verit_turn_in(ctx)
    end
  end

  defp verit_offer(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Suspicious Cat]")
      |> mes("Did you know that cats and dogs don't get along?")
      |> next()
      |> mes("[Suspicious Cat]")
      |> mes(
        "Look at that ugly and hideous Verit. He's scowling, wagging his tail and trying to come closer."
      )
      |> mes(
        "Oh, you don't have a tail, right? He thinks I'm a thorn in his side, and he's trying to start a fight now!"
      )
      |> next()
      |> mes("[Suspicious Cat]")
      |> mes(
        "Look at him, so greedy and drooly... I don't like the way he breathes, either. I can't stand how he's making those gobbling sounds..."
      )
      |> mes("It's so obvious that he's waiting to attack me from behind.")
      |> next()
      |> mes("[Suspicious Cat]")
      |> mes("Gosh, I could have scratched his face so hard if it wasn't for my stomachache!")
      |> mes("Hey, it's not because I'm afraid of Majoruros!")
      |> next()
      |> mes("[Suspicious Cat]")
      |> mes(
        "If you want to go home, you'd better beat up that ugly doggie! Otherwise, he'll bite you!"
      )
      |> next()
      |> select(["Help him", "Stay away"])

    case choice do
      1 ->
        ctx
        |> mes("[Suspicious Cat]")
        |> mes("Good, the target number is 20! Good luck!")
        |> setquest(@verit_hunt)
        |> close()

      _ ->
        ctx
        |> mes("[Suspicious Cat]")
        |> mes("Pah! You don't care about me? Fine, you traitor!")
        |> close()
    end
  end

  defp verit_in_progress(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Suspicious Cat]")
      |> mes("Is Verit's training going well?")
      |> next()
      |> select(["Sure.", "I want to stop."])

    case choice do
      1 ->
        ctx |> mes("[Suspicious Cat]") |> mes("Good. Keep up the good work!") |> close()

      _ ->
        ctx
        |> mes("[Suspicious Cat]")
        |> mes("What? You're so irresponsible!")
        |> erasequest(@verit_hunt)
        |> close()
    end
  end

  defp verit_turn_in(ctx) do
    ctx
    |> mes("[Suspicious Cat]")
    |> mes("Hey, you're actually useful! Good job!")
    |> mes("That Verit wouldn't dare come around here for a while, right? Muhahah!")
    |> changequest(@verit_hunt, @verit_cooldown)
    |> getexp(300_000, 100_000)
    |> close()
  end

  defp mummy_chain(ctx) do
    case checkquest(ctx, @mummy_cooldown, :playtime) do
      playtime when playtime in [0, 1] ->
        ctx
        |> mes("[Suspicious Cat]")
        |> mes(
          "Good, I'll make a good use of the time you gained! But I gotta do something about this stomachache first....."
        )
        |> close()

      2 ->
        ctx |> erasequest(@mummy_cooldown) |> mummy_hunting()

      _not_started ->
        mummy_hunting(ctx)
    end
  end

  defp mummy_hunting(ctx) do
    case checkquest(ctx, @mummy_hunt, :hunting) do
      -1 -> mummy_offer(ctx)
      hunting when hunting in [0, 1] -> mummy_in_progress(ctx)
      2 -> mummy_turn_in(ctx)
    end
  end

  defp mummy_offer(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Suspicious Cat]")
      |> mes("Precious treasures are supposed to be hidden in the deep secret places here!")
      |> mes("I'm sure the mummy's precious treasures are hidden in the second basement level.")
      |> next()
      |> mes("[Suspicious Cat]")
      |> mes("But Ancient Mummies caught me off guard and hit my head before I knew it!")
      |> next()
      |> mes("[Suspicious Cat]")
      |> mes(
        "I'm sure they're trying to stop me from finding the treasures by decreasing my superior brain cells!!"
      )
      |> next()
      |> mes("[Suspicious Cat]")
      |> mes("They can't stop me! Let's go get rid of Ancient Mummies!!")
      |> next()
      |> mes("[Suspicious Cat]")
      |> mes(
        "Don't ask why! I'm sure you wouldn't want those beautiful treasures to be hidden in the dark either!"
      )
      |> next()
      |> select(["Help him", "Stay away"])

    case choice do
      1 ->
        ctx
        |> mes("[Suspicious Cat]")
        |> mes("Alright, the target number is 20! Good luck!")
        |> setquest(@mummy_hunt)
        |> close()

      _ ->
        ctx
        |> mes("[Suspicious Cat]")
        |> mes("Bah, you're so cold-hearted.")
        |> close()
    end
  end

  defp mummy_in_progress(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Suspicious Cat]")
      |> mes("Is fighting Ancient Mummies going well?")
      |> next()
      |> select(["Sure.", "I want to stop."])

    case choice do
      1 ->
        ctx |> mes("[Suspicious Cat]") |> mes("Good. Keep up the good work!") |> close()

      _ ->
        ctx
        |> mes("[Suspicious Cat]")
        |> mes("What? You're so irresponsible!")
        |> erasequest(@mummy_hunt)
        |> close()
    end
  end

  defp mummy_turn_in(ctx) do
    ctx
    |> mes("[Suspicious Cat]")
    |> mes("Hey, you're actually useful! Good job!")
    |> mes("That Ancient Mummy wouldn't dare come around here for a while, right? Muhahah!")
    |> changequest(@mummy_hunt, @mummy_cooldown)
    |> getexp(600_000, 200_000)
    |> close()
  end
end
