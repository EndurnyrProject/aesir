defmodule Aesir.Commons.StatusParamsTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.StatusParams

  test "classic attribute ids are unchanged" do
    assert StatusParams.str() == 13
    assert StatusParams.agi() == 14
    assert StatusParams.vit() == 15
    assert StatusParams.int() == 16
    assert StatusParams.dex() == 17
    assert StatusParams.luk() == 18
    assert StatusParams.ustr() == 32
    assert StatusParams.uagi() == 33
    assert StatusParams.uvit() == 34
    assert StatusParams.uint() == 35
    assert StatusParams.udex() == 36
    assert StatusParams.uluk() == 37
  end

  test "trait base stat ids" do
    assert StatusParams.pow() == 219
    assert StatusParams.sta() == 220
    assert StatusParams.wis() == 221
    assert StatusParams.spl() == 222
    assert StatusParams.con() == 223
    assert StatusParams.crt() == 224
  end

  test "derived combat stat ids" do
    assert StatusParams.patk() == 225
    assert StatusParams.smatk() == 226
    assert StatusParams.res() == 227
    assert StatusParams.mres() == 228
    assert StatusParams.hplus() == 229
    assert StatusParams.crate() == 230
  end

  test "trait point and AP ids" do
    assert StatusParams.trait_point() == 231
    assert StatusParams.ap() == 232
    assert StatusParams.max_ap() == 233
  end

  test "trait upper stat ids" do
    assert StatusParams.upow() == 247
    assert StatusParams.usta() == 248
    assert StatusParams.uwis() == 249
    assert StatusParams.uspl() == 250
    assert StatusParams.ucon() == 251
    assert StatusParams.ucrt() == 252
  end

  test "attributes/0 still returns only classic stat ids" do
    assert StatusParams.attributes() == [
             :str,
             :agi,
             :vit,
             :int,
             :dex,
             :luk,
             :ustr,
             :uagi,
             :uvit,
             :uint,
             :udex,
             :uluk
           ]
  end
end
