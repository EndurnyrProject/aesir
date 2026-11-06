defmodule Aesir.ZoneServer.Content.Npc.Functions.FKafstor do
  @moduledoc """
  Opens the Kafra storage, charging the access fee unless a ticket covers it.

  ## Behavior

  A normal Kafra refuses characters without Basic Skill level 6 and characters who cannot pay the
  fee, in both cases with the Niflheim variant of the message when that Kafra is used. A Free
  Storage Ticket skips the fee; paying it awards Special Reserve Points. Guild-castle Kafras
  (`type` 2) skip the fee and the farewell entirely, and the guild storage itself is not
  implemented yet.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - kobra_k88
    - L0ne_W0lf
    - Joseph
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script kafras/functions_kafras.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Content.Npc.Functions.FCanopenstorage
  alias Aesir.ZoneServer.Content.Npc.Functions.FCheckkafcode
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena
  alias Aesir.ZoneServer.Script.Todo

  @storage_ticket 7059
  @reserve_point_divisor 5
  @niflheim_thanks_repeats 5

  @doc """
  Callable rAthena global function `F_KafStor(type, fee, welcome)`; throws `{:script_end, ctx}` once
  the storage is open.
  """
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), nil} | no_return()
  def call(ctx, args) do
    type = Enum.at(args, 0, 0)
    niflheim? = Enum.at(args, 2, 0) == 1

    try do
      if type == 1 do
        guild_storage(ctx)
      else
        open(ctx, type, niflheim?, Enum.at(args, 1, 0))
      end
    catch
      :throw, {:script_return, result} -> result
    end
  end

  defp guild_storage(ctx) do
    # `guildopenstorage` has no engine implementation yet; it raises when a guild Kafra is used.
    if Rathena.truthy?(Todo.call!(:guildopenstorage, [])) do
      ctx
      |> mes("[Kafra Employee]")
      |> mes("I'm sorry but another guild member is using the guild storage")
      |> mes("right now.  Please wait until that person is finished.")
      |> close()
      |> cutin("", 255)
      |> halt()
    else
      ctx |> cutin("", 255) |> close() |> halt()
    end
  end

  defp open(ctx, type, niflheim?, fee) do
    {ctx, allowed} = FCanopenstorage.call(ctx, [])

    if Rathena.truthy?(allowed) do
      ctx = ctx |> charge(type, fee, niflheim?) |> farewell(type, niflheim?)
      {ctx, _code} = FCheckkafcode.call(ctx, [])

      halt(ctx |> close() |> openstorage() |> cutin("", 255))
    else
      refuse(ctx, niflheim?)
    end
  end

  defp refuse(ctx, niflheim?) do
    ctx = mes(ctx, "[Kafra Employee]")

    if niflheim? do
      ctx =
        ctx
        |> mes("^666666S-s-ssoooorry,")
        |> mes("y-you're a-a-aaaa")
        |> mes("Nooviiice... N-neeeds")
        |> mes("B-basic sssskill l-level 6...^000000")

      {ctx, nil}
    else
      ctx =
        ctx
        |> mes("I'm sorry, but you")
        |> mes("need the Novice's")
        |> mes("Basic Skill Level 6 to")
        |> mes("use the Storage Service.")

      {ctx, nil}
    end
  end

  defp charge(ctx, 2, _fee, _niflheim?), do: ctx

  defp charge(ctx, _type, fee, niflheim?) do
    if Rathena.truthy?(count_item(ctx, @storage_ticket)),
      do: delitem(ctx, @storage_ticket, 1),
      else: charge_fee(ctx, fee, niflheim?)
  end

  defp charge_fee(ctx, fee, niflheim?) do
    if zeny(ctx) < fee do
      refuse_fee(ctx, fee, niflheim?)
    else
      ctx
      |> pay_zeny(fee)
      |> set_char_var(
        :RESRVPTS,
        get_char_var(ctx, :RESRVPTS, 0) + div(fee, @reserve_point_divisor)
      )
    end
  end

  defp refuse_fee(ctx, fee, niflheim?) do
    ctx = ctx |> mes("[Kafra Employee]") |> fee_refusal(fee, niflheim?)
    halt_with_nil(ctx)
  end

  defp fee_refusal(ctx, _fee, true) do
    ctx
    |> percent_heal(hp: -50, sp: -50)
    |> mes("^666666Zeeeeeny...")
    |> mes("M-more z-zeny...!")
    |> mes("N-neeed 150... zeny...")
    |> mes("Ergh! T-taking bl-blood~!^000000")
  end

  defp fee_refusal(ctx, fee, _niflheim?) do
    ctx
    |> mes("I'm sorry, but you don't")
    |> mes("have enough zeny to use")
    |> mes("the Storage Service. Our")
    |> mes("Storage access fee is #{fee} zeny.")
  end

  defp farewell(ctx, 2, _niflheim?), do: ctx

  defp farewell(ctx, _type, true) do
    ctx
    |> percent_heal(hp: 0, sp: -10)
    |> mes("[Kafra Employee]")
    |> repeat_thanks(@niflheim_thanks_repeats)
  end

  defp farewell(ctx, _type, _niflheim?) do
    ctx
    |> mes("[Kafra Employee]")
    |> mes("Here, let me open")
    |> mes("your Storage for you.")
    |> mes("Thank you for using")
    |> mes("the Kafra Service.")
  end

  defp repeat_thanks(ctx, remaining) when remaining > 0 do
    ctx
    |> mes("^666666Thank you.. for... using...^000000")
    |> repeat_thanks(remaining - 1)
  end

  defp repeat_thanks(ctx, 0), do: ctx

  defp halt(ctx), do: throw({:script_end, ctx})
  defp halt_with_nil(ctx), do: throw({:script_return, {ctx, nil}})
end
