defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Okolnir.WishMaiden1 do
  @moduledoc """
  Awards the guild leader's Okolnir prize.

  ## Behavior

  - Exchanges the required materials for a divine item and a Valkyrie gift.
  - Opens the return gate and manages the instance's expiration.

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
        map: "que_qaru01",
        x: 252,
        y: 340,
        dir: 3,
        sprite: 403,
        name: "Wish Maiden",
        scope: :shared,
        unique_name: "Wish Maiden#aru01_gift"
      },
      %{
        map: "que_qaru02",
        x: 252,
        y: 340,
        dir: 3,
        sprite: 403,
        name: "Wish Maiden",
        scope: :shared,
        unique_name: "Wish Maiden#aru02_gift"
      },
      %{
        map: "que_qaru03",
        x: 252,
        y: 340,
        dir: 3,
        sprite: 403,
        name: "Wish Maiden",
        scope: :shared,
        unique_name: "Wish Maiden#aru03_gift"
      },
      %{
        map: "que_qaru04",
        x: 252,
        y: 340,
        dir: 3,
        sprite: 403,
        name: "Wish Maiden",
        scope: :shared,
        unique_name: "Wish Maiden#aru04_gift"
      },
      %{
        map: "que_qaru05",
        x: 252,
        y: 340,
        dir: 3,
        sprite: 403,
        name: "Wish Maiden",
        scope: :shared,
        unique_name: "Wish Maiden#aru05_gift"
      },
      %{
        map: "que_qsch01",
        x: 252,
        y: 340,
        dir: 3,
        sprite: 403,
        name: "Wish Maiden",
        scope: :shared,
        unique_name: "Wish Maiden#sch01_gift"
      },
      %{
        map: "que_qsch02",
        x: 252,
        y: 340,
        dir: 3,
        sprite: 403,
        name: "Wish Maiden",
        scope: :shared,
        unique_name: "Wish Maiden#sch02_gift"
      },
      %{
        map: "que_qsch03",
        x: 252,
        y: 340,
        dir: 3,
        sprite: 403,
        name: "Wish Maiden",
        scope: :shared,
        unique_name: "Wish Maiden#sch03_gift"
      },
      %{
        map: "que_qsch04",
        x: 252,
        y: 340,
        dir: 3,
        sprite: 403,
        name: "Wish Maiden",
        scope: :shared,
        unique_name: "Wish Maiden#sch04_gift"
      },
      %{
        map: "que_qsch05",
        x: 252,
        y: 340,
        dir: 3,
        sprite: 403,
        name: "Wish Maiden",
        scope: :shared,
        unique_name: "Wish Maiden#sch05_gift"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FOkolnir
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    ctx = set_local(ctx, :"sub$", sub)
    name = strnpcinfo(ctx, 4)

    castle_prefix =
      if Rathena.truthy?(Rathena.compare(name, "aru")), do: "arug_cas0", else: "schg_cas0"

    castle =
      Rathena.concat(
        castle_prefix,
        Rathena.charat(strnpcinfo(ctx, 4), Rathena.getstrlen(strnpcinfo(ctx, 4)) - 1)
      )

    ctx = set_local(ctx, :"t$", castle)
    guild = castle_data(ctx, castle, 1)
    ctx = set_local(ctx, :GID, guild)

    cond do
      getcharid(ctx, 2) != guild -> cutin(ctx, "wish_maiden11", 255)
      is_guild_leader(ctx) != 1 -> ctx |> member_dialogue() |> cutin("wish_maiden11", 255)
      true -> leader_reward(ctx, sub, guild)
    end
  end

  defp leader_reward(ctx, sub, guild) do
    {items, reward} =
      if Rathena.truthy?(Rathena.compare(sub, "aru")) do
        {[7835, 1, 7836, 1, 7837, 1, 7838, 1, 2513, 1, 7291, 10, 7293, 10, 7063, 100, 985, 20],
         2541}
      else
        {[7830, 1, 7831, 1, 7832, 1, 7833, 1, 7834, 1, 2357, 1, 7510, 100, 969, 10, 985, 20],
         2383}
      end

    ctx = ctx |> set_local(:n, items) |> set_local(:rwd, reward) |> set_local(:i, 0)
    ctx = check_materials(ctx, Enum.chunk_every(items, 2))

    if get_local(ctx, :check, 0) >= 9 do
      grant_reward(ctx, sub, guild, reward, Enum.chunk_every(items, 2))
    else
      ctx
      |> cutin("wish_maiden13", 1)
      |> mes("[Wish Maiden]")
      |> mes(
        Rathena.concat(
          Rathena.concat(
            "As I declared, you are worthy of holding the ",
            Rathena.getitemname(reward)
          ),
          "."
        )
      )
      |> mes("However, you do not have the requirements on you...")
      |> next()
      |> mes("[Wish Maiden]")
      |> mes("...Did you forget something?")
      |> close()
      |> cutin("wish_maiden11", 255)
    end
  end

  defp check_materials(ctx, items) do
    Enum.reduce(items, ctx, fn [item, amount], acc ->
      acc =
        if count_item(acc, item) >= amount,
          do: set_local(acc, :check, get_local(acc, :check, 0) + 1),
          else: acc

      set_local(acc, :i, get_local(acc, :i, 0) + 2)
    end)
  end

  defp grant_reward(ctx, sub, guild, reward, items) do
    ctx =
      ctx
      |> cutin("wish_maiden12", 1)
      |> mes("[Wish Maiden]")
      |> mes("As I declared, I will give the Goddess' shine to you.")
      |> mes("You have the requirements to carry it...")
      |> next()
      |> mes("[Wish Maiden]")
      |> mes("You will be granted the power of the great Valkyrie...")
      |> next()
      |> mes("[Wish Maiden]")
      |> mes("I will give you some things for fun.")
      |> mes("All of you enjoy them together...")
      |> next()
      |> mes("[Wish Maiden]")
      |> mes("Go to Rachel and Juno to meet the Ravies sisters.")
      |> next()
      |> cutin("wish_maiden32", 1)
      |> mes("[Wish Maiden]")
      |> mes("I will open the gate for you to come back here.")
      |> mes("...Okolnir won't last forever...")
      |> set_local(:i, 0)

    ctx =
      Enum.reduce(items, ctx, fn [item, amount], acc ->
        acc |> delitem(item, amount) |> set_local(:i, get_local(acc, :i, 0) + 2)
      end)

    ctx = ctx |> give_item(reward, 1) |> give_item(7840, 1)

    message =
      Rathena.concat(
        Rathena.concat(
          Rathena.concat(
            Rathena.concat(
              Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "], of guild ["),
              getguildname(ctx, guild)
            ),
            "] has brought a "
          ),
          Rathena.getitemname(reward)
        ),
        " into this world."
      )

    ctx
    |> announce(message, 0, "0x70dbdb")
    |> close()
    |> cutin("wish_maiden11", 255)
    |> disablenpc(Rathena.concat(Rathena.concat("Wish Maiden#", sub), "_gift"))
    |> enablenpc(Rathena.concat(Rathena.concat("#to_agit_", sub), "_gate"))
  end

  defp member_dialogue(ctx) do
    ctx
    |> cutin("wish_maiden12", 1)
    |> mes("[Wish Maiden]")
    |> mes("All of you worked together as a team...")
    |> mes("Humans are strong when they are united, but are easily swayed by lust.")
    |> next()
    |> mes("[Wish Maiden]")
    |> mes("Humans are imperfect, so their chief god is there for them when they need help.")
    |> mes("....")
    |> next()
    |> mes("[Wish Maiden]")
    |> mes("Always be real.")
    |> mes("Do not regret your actions...")
    |> close()
  end

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnEnable", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    ctx |> set_local(:"sub$", sub) |> enablenpc("Wish Maiden##{sub}_gift") |> initnpctimer()
  end

  def on_event("OnDisable", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    ctx |> set_local(:"sub$", sub) |> disablenpc("Wish Maiden##{sub}_gift") |> stopnpctimer()
  end

  def on_event("OnTimer280000", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])

    ctx
    |> set_local(:"sub$", sub)
    |> mapannounce(
      "que_q#{sub}",
      "Wish Maiden : ... Okolnir will soon disappear... I will send you back to where you originally came from.",
      1,
      "0x00ff00"
    )
  end

  def on_event("OnTimer290000", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    ctx = set_local(ctx, :"sub$", sub)

    ctx
    |> mapwarp("que_q#{sub}", get_local(ctx, :"t$", ""), 157, 369)
    |> donpcevent("#to_agit_#{sub}_gate::OnDisable")
  end

  def on_event("OnTimer300000", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])

    ctx
    |> set_local(:"sub$", sub)
    |> donpcevent("#okolnir_#{sub}::OnDisable")
    |> setd("$@gqse_#{sub}_miro", 0)
    |> setd("$@gqse_#{sub}_pcc", 0)
    |> setd("$@gqse_#{sub}_gd", 0)
    |> setd("$@gqse_#{sub}_nm", 0)
    |> setd("$siz_#{sub}_on", 2)
    |> donpcevent("#okolnir_#{sub}_time01::OnEnable")
    |> stopnpctimer()
  end

  def on_event("OnInit", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    ctx |> set_local(:"sub$", sub) |> disablenpc("Wish Maiden##{sub}_gift")
  end
end
