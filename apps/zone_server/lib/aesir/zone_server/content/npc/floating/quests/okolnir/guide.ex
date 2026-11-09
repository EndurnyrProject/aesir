defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Okolnir.Guide do
  @moduledoc """
  Guides the castle's guild members to Okolnir.

  ## Behavior

  - Explains Okolnir and the castle requirements for entry.
  - Removes crystal keys and sends eligible guild members to Okolnir.
  - Reports when the realm is unavailable or being built.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Joseph
    - L0ne_W0lf
    - Toshiro90
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/okolnir.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "arug_cas01",
        x: 161,
        y: 371,
        dir: 3,
        sprite: 899,
        name: "Guide",
        scope: :shared,
        unique_name: "Guide#gq_aru01"
      },
      %{
        map: "arug_cas02",
        x: 349,
        y: 347,
        dir: 3,
        sprite: 899,
        name: "Guide",
        scope: :shared,
        unique_name: "Guide#gq_aru02"
      },
      %{
        map: "arug_cas03",
        x: 324,
        y: 161,
        dir: 3,
        sprite: 899,
        name: "Guide",
        scope: :shared,
        unique_name: "Guide#gq_aru03"
      },
      %{
        map: "arug_cas04",
        x: 324,
        y: 161,
        dir: 3,
        sprite: 899,
        name: "Guide",
        scope: :shared,
        unique_name: "Guide#gq_aru04"
      },
      %{
        map: "arug_cas05",
        x: 324,
        y: 161,
        dir: 3,
        sprite: 899,
        name: "Guide",
        scope: :shared,
        unique_name: "Guide#gq_aru05"
      },
      %{
        map: "schg_cas01",
        x: 376,
        y: 307,
        dir: 3,
        sprite: 899,
        name: "Guide",
        scope: :shared,
        unique_name: "Guide#gq_sch01"
      },
      %{
        map: "schg_cas02",
        x: 181,
        y: 335,
        dir: 3,
        sprite: 899,
        name: "Guide",
        scope: :shared,
        unique_name: "Guide#gq_sch02"
      },
      %{
        map: "schg_cas03",
        x: 84,
        y: 101,
        dir: 3,
        sprite: 899,
        name: "Guide",
        scope: :shared,
        unique_name: "Guide#gq_sch03"
      },
      %{
        map: "schg_cas04",
        x: 376,
        y: 307,
        dir: 3,
        sprite: 899,
        name: "Guide",
        scope: :shared,
        unique_name: "Guide#gq_sch04"
      },
      %{
        map: "schg_cas05",
        x: 376,
        y: 307,
        dir: 3,
        sprite: 899,
        name: "Guide",
        scope: :shared,
        unique_name: "Guide#gq_sch05"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FOkolnir
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    ctx = ctx |> set_local(:"sub$", sub) |> enablenpc(Rathena.concat("Guide#gq_", sub))
    if getd(ctx, status_key(sub)) == 1, do: setd(ctx, status_key(sub), 0), else: ctx
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    ctx = set_local(ctx, :"sub$", sub)
    ctx = set_local(ctx, :GID, castle_data(ctx, to_string(strnpcinfo(ctx, 4)), 1))

    if getcharid(ctx, 2) == get_local(ctx, :GID, 0) do
      guide_guild_member(ctx, sub)
    else
      ctx
      |> mes("[Guide]")
      |> mes("... I've never seen you before.")
      |> mes("You are strangers here. You'd better get out of here right now.")
      |> close()
    end
  end

  defp guide_guild_member(ctx, sub) do
    cond do
      getd(ctx, status_key(sub)) == 0 ->
        offer_entry(ctx, sub)

      getd(ctx, status_key(sub)) == 1 ->
        open_entry(ctx, sub)

      getd(ctx, status_key(sub)) == 2 ->
        ctx
        |> mes("[Guide]")
        |> mes("Building Okolnir needs quite a long time.")
        |> mes("....even though it's only virtual...")
        |> next()
        |> mes("[Guide]")
        |> mes("It takes about 12 - 13 hours to create the virtual realm.")
        |> close()

      true ->
        ctx |> mes("[Guide]") |> mes("You'll have to wait.") |> close()
    end
  end

  defp offer_entry(ctx, sub) do
    {ctx, choice} =
      ctx
      |> mes("[Guide]")
      |> mes("This castle has a hidden secret.")
      |> mes("That is the ^4d4dff'Okolnir'^000000.")
      |> next()
      |> select(["About Okolnir.", "Go to Okolnir.", "Cancel."])

    case choice do
      1 -> explain_okolnir(ctx)
      2 -> check_castle(ctx, sub)
      3 -> close(ctx)
      _ -> ctx
    end
  end

  defp explain_okolnir(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Guide]")
      |> mes("Okolnir is a kind of virtual realm...")
      |> mes("I don't know how Okolnir exists, but I guess only Valkyrie knows.")
      |> next()
      |> mes("[Guide]")
      |> mes("As you know this is a place to test the adventurers made by Valkyrie...")
      |> mes("...you know the qualifications to enter Okolnir.")
      |> next()
      |> select(["Qualifications?"])

    ctx
    |> mes("[Guide]")
    |> mes("Yes, Valkyrie definitely prefers strong adventurers.")
    |> mes("Only the qualified can enter Okolnir and Valhalla.")
    |> next()
    |> mes("[Guide]")
    |> mes("It only opens when everyone comes together to work it out.")
    |> mes("The key is in the castle.")
    |> next()
    |> mes("[Guide]")
    |> mes(
      "If a castle's ^4d4dffeconomy is over 65 and defense also over 30^000000, this will be acceptable to access Okolnir."
    )
    |> next()
    |> mes("[Guide]")
    |> mes("And, if you pass all of the tests given by Valkyrie in Okolnir!")
    |> mes("You will also receive a mysterious gift.")
    |> next()
    |> mes("[Guide]")
    |> mes("Would you like to try to enter here?")
    |> close()
  end

  defp check_castle(ctx, sub) do
    ctx = set_local(ctx, :Defence, castle_data(ctx, to_string(strnpcinfo(ctx, 4)), 3))
    ctx = set_local(ctx, :Economy, castle_data(ctx, to_string(strnpcinfo(ctx, 4)), 2))

    if get_local(ctx, :Economy, 0) > 64 and get_local(ctx, :Defence, 0) > 29 do
      {ctx, choice} =
        ctx
        |> mes("[Guide]")
        |> mes("Great! Economy and Defense are OK.")
        |> mes("You can enter Okolnir now....")
        |> mes("Do you want to go there?")
        |> next()
        |> select(["Sure let's go there.", "No."])

      case choice do
        1 ->
          ctx =
            if Rathena.truthy?(count_item(ctx, 7839)),
              do: delitem(ctx, 7839, count_item(ctx, 7839)),
              else: ctx

          ctx
          |> mes("[Guide]")
          |> mes("Ok......")
          |> mes("Please follow me...")
          |> close()
          |> warp(Rathena.concat("que_q", sub), 346, 32)

        2 ->
          ctx
          |> mes("[Guide]")
          |> mes("You can try this anytime in the future...")
          |> mes("If you are ready to protect this castle.")
          |> close()

        _ ->
          ctx
      end
    else
      ctx
      |> mes("[Guide]")
      |> mes("You are not qualified yet.")
      |> mes("Please develop your castle more...")
      |> close()
    end
  end

  defp open_entry(ctx, sub) do
    {ctx, choice} =
      ctx
      |> mes("[Guide]")
      |> mes("... OK...")
      |> mes("Good luck.")
      |> next()
      |> select(["Enter now.", "No."])

    case choice do
      1 ->
        ctx =
          if count_item(ctx, 7839) > 0, do: delitem(ctx, 7839, count_item(ctx, 7839)), else: ctx

        ctx
        |> mes("[Guide]")
        |> mes("Hope you get everything you want...")
        |> close()
        |> warp(Rathena.concat("que_q", sub), 346, 32)

      2 ->
        ctx |> mes("[Guide]") |> mes("Really?") |> mes("Sorry to hear that.") |> close()

      _ ->
        ctx
    end
  end

  defp status_key(sub), do: Rathena.concat(Rathena.concat("$siz_", sub), "_on")
end
